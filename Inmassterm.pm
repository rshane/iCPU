#!/usr/bin/perl
package QP::Socket::Inmassterm;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw( inmassterm );

use lib '/var/www/lib'; 
use QP::Socket::Base; 
use Time::HiRes qw(usleep); 
use strict; 

use constant IAC         => 0xFF; 
use constant SB          => 0xFA; 
use constant SE          => 0xF0; 
use constant WILL        => 0xFB; 
use constant WONT        => 0xFC; 
use constant DO          => 0xFD; 
use constant DONT        => 0xFE; 

use constant AUTH_OPT    => 0x25; 
use constant BINARY      => 0x00; 
use constant ECHO        => 0x01; 
use constant NEW_ENV     => 0x27; 
use constant SUPPRESS_GA => 0x03; 
use constant TERM_SPEED  => 0x20; 
use constant TERM_TYPE   => 0x18; 
use constant WIN_SIZE    => 0x1F; 

#use constant QPD        => new QP::Debug; 

use constant SEND_DELAY  => 500000; 
use constant KEY_DELAY   => 100000; 
use constant MAX_ATTEMPT => 30; 

use constant ADDR	 => '10.2.0.101'; #'10.0.21.69';
use constant PORT	 => '23';
use constant LOGIN	 => "Bobby\r\n"; #"apache\r\n";
use constant PASS	 => "windows\r\n"; #"Glavda,\r\n";



sub inmassterm {
my %args = @_;
my $debug  = $args{debug};
my $script = $args{data};



$|=1; 
my $PART_NUMBER; 
my $FILE; 


my $addr         = ADDR(); 
my $port         = PORT(); 
my $self         = QP::Socket::Base->new($addr, $port); 
my $socket       = $self->socket; 
my $select       = $self->select; 
my $IP; 
my $TERM         = [[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[]]; 
my $X            = 1; 
my $Y            = 1; 
my $xlast        = $X; 
my $ylast        = $Y; 
my $isIAC        = 0; 
my $isCapability = 0; 
my $isCommand    = 0; 
my $isOption     = 0; 
my $isANSI       = 0; 
my $isCSI        = 0; 
my $isESC        = 0; 
my $XML; 

my $loop_locations; 
$loop_locations = sub { 
    my $type = shift; 
    my $cmd = shift; 
    my $status = grab_screenline(1); 
    my $line; 

    #QPD->DEBUG("status=($status)"); 
    if ($status !~ /End of Locations/) { 
	$line = grab_screenline(3); 
	my ($item) = $line =~ /Item\s+(\S+)\s+$/; 

	$line = grab_screenline(4); 
	my ($description) = $line =~ /Description\s+(\S+)\s+$/; 

	$line = grab_screenline(8); 
	my ($wh) = $line =~ /Warehouse\s+\*(\S+)\s+$/; 

	$line = grab_screenline(9); 
	my ($loc) = $line =~ /Location\s+\*(\S+)\s+$/; 

	$line = grab_screenline(13); 
	my ($available) = $line =~ /Bal. Available\s+(\S+)\s+$/; 

	$line = grab_screenline(14); 
	my ($allocated) = $line =~ /Bal. Allocated\s+(\S+)\s+$/; 

	$line = grab_screenline(15); 
	my ($onhold) = $line =~ /Bal. On Hold\s+(\S+)\s+$/; 

	$XML .= "<location>". 
	    "<wh>$wh</wh>". 
	    "<loc>$loc</loc>". 
	    "<available>$available</available>". 
	    "<allocated>$allocated</allocated>". 
	    "<onhold>$onhold</onhold>". 
	    "</location>\n"; 

	# Preempt TAB command 
	# Simulate loop by inserting identical command in queue 
	unshift @$IP, ['INMASS', '9', 'Location', 'TAB', $loop_locations]; 
	# Return new type 
	# Return new command 
	$cmd = 'DOWNARROW'; 
    } 
    return ($type, $cmd); 
}; 

# Format = [Category, Pattern, Row, Command, Pre-exec] 
#   Category : Currently only CMD or INMASS 
#   Row      : Row to search 
#   Pattern  : Regex to match 
#   Command  : DOS/INMASS Command to exec if match 
#   Pre-exec : Optional. Reference to Perl function to exec before DOS/INMASS Command. 
#              Useful for gathering results from previous Command. 


my $CMD2INMASS = [ 
    ['CMD', 'PROMPT', 'C:.+>', 'set console=001&net use m: \\\\10.0.21.2\\bindata /user:toor Qual-ProPassword4Inmass&m:&inmass'], 
    ['INMASS', '', 'Select company number:', '00'], 

    #['CMD', 'PROMPT', 'C:.+>', 'set console=001'], 
    #['CMD', 'PROMPT', 'C:.+>', 'm:'], 
    #['CMD', 'PROMPT', 'M:.+>', 'inmass'], 
    #['INMASS', '', 'Select company number:', '99'], 

    ['INMASS', '', 'Select company number:', 'ENTER'], 
    ['INMASS', '', 'Enter password', 'nokia'], 
    ['INMASS', '', 'Enter password', 'ENTER'], 
    ['INMASS', '', 'Enter Date', 'ENTER'], 
    ]; 

my $INMASS2CMD = [ 
    ['INMASS', '14', '16. Exit', '16'], 
    ['INMASS', '14', '16. Exit', 'ENTER'], 

    ['CMD', '', '.', 'ENTER'], 
    ['CMD', 'PROMPT', 'M:.+>', 'exit'], 
    ]; 

my $GET_PART_QTYS = [ 
    # Go to Inventory File Inquiry 
    ['INMASS', '7',  '1. Inventory Control', '1'], 
    ['INMASS', '7',  '1. Inventory Control', 'ENTER'], 
    ['INMASS', '9',  '4. Inventory File Inquiry', '4'], 
    ['INMASS', '9',  '4. Inventory File Inquiry', 'ENTER'], 
    # Lookup locations 
    ['INMASS', '2',  'Inventory Inquiry by Item', $PART_NUMBER], 
    ['INMASS', '2',  'Inventory Inquiry by Item', 'ENTER'], 
    ['INMASS', '24', 'Enter Your Choice', '4'], 
    ['INMASS', '24', 'Enter Your Choice', 'ENTER'], 
    ['INMASS', '8',  'Warehouse', 'IN'], 
    ['INMASS', '8',  'Warehouse', 'ENTER'], 
    ['INMASS', '9',  'Location', 'DOWNARROW'], 
    ['INMASS', '9',  'Location', 'TAB', $loop_locations], 
    ['INMASS', '8',  'Warehouse.+IN', 'WP'], 
    ['INMASS', '8',  'Warehouse', 'ENTER'], 
    ['INMASS', '9',  'Location', 'DOWNARROW'], 
    ['INMASS', '9',  'Location', 'TAB', $loop_locations], 
    ['INMASS', '8',  'Warehouse.+WP', 'TAB'], 
    ['INMASS', '24', 'Enter Your Choice', 'TAB'], 
    ['INMASS', '2',  'Inventory Inquiry by Item.+'.$PART_NUMBER, 'ESCAPE'], 
    # Exit to main menu 
    ['INMASS', '21', '16. Return to INMASS-II', '16'], 
    ['INMASS', '21', '16. Return to INMASS-II', 'ENTER'], 
    ]; 


my $GET_QTYS = [ 
    @$CMD2INMASS, 
    @$GET_PART_QTYS, 
    @$INMASS2CMD, 
    ]; 


my $BASIC_TEST = [ 
    ['CMD', 'PROMPT', 'C:.+>', 'dir'], 
    ['CMD', 'PROMPT', 'C:.+>', 'exit'], 

    #['CMD', 'PROMPT', 'C:.+>', 'net use p: \\\\10.0.21.3\tmp /user:toor Glavda,'], 
    #['CMD', 'PROMPT', 'C:.+>', 'p:'], 
    #['CMD', 'PROMPT', 'P:.+>', 'set console=001'], 
    #['CMD', 'PROMPT', 'P:.+>', 'dir'], 
    #['CMD', 'PROMPT', 'P:.+>', 'exit'], 

    #@$CMD2INMASS, 
    #@$INMASS2CMD, 
    ]; 

sub num2hex { 
    my $num = shift; 
    my $hex = sprintf "%02x", $num; 
    return $hex; 
} 

sub str2chars { 
    my $str = shift; 
    my @chars = $str =~ /(.)/g; 
    return @chars; 
} 

sub Xbound { 
    $X = 80 if ($X > 80); 
    $X = 1 if ($X < 1); 
} 

sub Ybound { 
    $Y = 25 if ($Y > 25); 
    $Y = 1 if ($Y < 1); 
} 

sub init_term { 
    my $param = shift; 
    my $row; 
    my $col; 

    if ($param eq '') { 
	for $row ($Y..25) { 
	    for $col (1..80) { 
		$TERM->[$row - 1]->[$col - 1] = '`'; 
	    } 
	} 
    } 
    if ($param eq '1') { 
	for $row (1..$Y) { 
	    for $col (1..80) { 
		$TERM->[$row - 1]->[$col - 1] = '`'; 
	    } 
	} 
    } 
    if ($param eq '2') { 
	for $row (1..25) { 
	    for $col (1..80) { 
		$TERM->[$row - 1]->[$col - 1] = '`'; 
	    } 
	} 
    } 
} 


sub init_line { 
    my $param = shift; 
    my $col; 

    if ($param eq '') { 
	for $col ($X..80) { 
	    $TERM->[$Y - 1]->[$col - 1] = '`'; 
	} 
	return; 
    } 
    if ($param eq '1') { 
	for $col (1..$X) { 
	    $TERM->[$Y - 1]->[$col - 1] = '`'; 
	} 
	return; 
    } 
    if ($param eq '2') { 
	for $col (1..80) { 
	    $TERM->[$Y - 1]->[$col - 1] = '`'; 
	} 
	return; 
    } 
} 


sub poke_term { 
    my $char = shift; 

    #if ((hex($char) < 0x7E) && (hex($char) > 0x1F)) { 
    #} 

    $TERM->[$Y - 1]->[$X - 1] = chr(hex($char)); 
    $X++; 
    Xbound; 
} 

sub draw_term { 
    my $row; 
    my $col; 
    for $row (1..25) { 
	#QPD->DEBUG("row=($row), col=($col)"); 
	for $col (1..80) { 
	    print $TERM->[$row - 1]->[$col - 1]; 
	} 
	print "\n"; 
    } 
    #QPD->DEBUG("row=($row), col=($col)"); 
} 


sub onScreen { 
    my $pattern = shift || return 0; 
    my $row = shift; 

    if ($row eq 'PROMPT') { 
	$row = $Y; 
    } 

    my $ubound = $row || 25; 
    my $lbound = $row || 1; 
    my $i; 
    for $i ($lbound..$ubound) { 
	my $line = join '', @{$TERM->[$i - 1]}; 
	if ($line =~ /$pattern/) { 
	    #QPD->DEBUG("Pattern=($pattern) found at row=($row), ubound=($ubound), lbound=($lbound)"); 
	    return 1; 
	} 
    } 
    return 0; 
} 

sub grab_screenline { 
    my $row = shift; 
    my $line = join '', @{$TERM->[$row - 1]}; 
    return $line; 
} 


sub get_capability { 
    my $capability = shift; 

    if ($capability eq num2hex(AUTH_OPT)) { 
	#QPD->DEBUG("Capability: AUTH_OPT"); 
    } 
    if ($capability eq num2hex(BINARY)) { 
	#QPD->DEBUG("Capability: BINARY"); 
    } 
    if ($capability eq num2hex(ECHO)) { 
	#QPD->DEBUG("Capability: ECHO"); 
    } 
    if ($capability eq num2hex(NEW_ENV)) { 
	#QPD->DEBUG("Capability: NEW_ENV"); 
    } 
    if ($capability eq num2hex(SUPPRESS_GA)) { 
	#QPD->DEBUG("Capability: SUPPRESS_GA"); 
    } 
    if ($capability eq num2hex(TERM_SPEED)) { 
	#QPD->DEBUG("Capability: TERM_SPEED"); 
    } 
    if ($capability eq num2hex(TERM_TYPE)) { 
	#QPD->DEBUG("Capability: TERM_TYPE"); 
    } 
    if ($capability eq num2hex(WIN_SIZE)) { 
	#QPD->DEBUG("Capability: WIN_SIZE"); 
    } 
} 


sub get_command { 
    my $command = shift; 

    if ($command eq num2hex(AUTH_OPT)) { 
	#QPD->DEBUG("Command: AUTH_OPT"); 
	print $socket chr(IAC).chr(WONT).chr(AUTH_OPT); 
	#QPD->DEBUG("Sent AUTH_OPT WONT"); 
    } 
    if ($command eq num2hex(BINARY)) { 
	#QPD->DEBUG("Command: BINARY"); 
    } 
    if ($command eq num2hex(ECHO)) { 
	#QPD->DEBUG("Command: ECHO"); 
    } 
    if ($command eq num2hex(NEW_ENV)) { 
	#QPD->DEBUG("Command: NEW_ENV"); 
    } 
    if ($command eq num2hex(SUPPRESS_GA)) { 
	#QPD->DEBUG("Command: SUPPRESS_GA"); 
    } 
    if ($command eq num2hex(TERM_SPEED)) { 
	#QPD->DEBUG("Command: TERM_SPEED"); 
    } 
    if ($command eq num2hex(TERM_TYPE)) { 
	#QPD->DEBUG("Command: TERM_TYPE"); 
	print $socket chr(IAC).chr(WILL).chr(TERM_TYPE); 
	$isANSI = 1; 
	#QPD->DEBUG("Sent TERM_TYPE WILL"); 
    } 
    if ($command eq num2hex(WIN_SIZE)) { 
	#QPD->DEBUG("Command: WIN_SIZE"); 
	print $socket chr(IAC).chr(SB). 
	    chr(WIN_SIZE). 
	    chr(0x00).chr(0x50).chr(0x00).chr(0x18). 
	    chr(IAC).chr(SE); 
	#QPD->DEBUG("Sent WIN_SIZE Size"); 
    } 
} 


sub get_option { 
    my $char = shift; 
    my $option = shift; 
    my ($control, $params) = $option =~ /^(..)(.+)$/; 
    my $code; 

    if ($control eq num2hex(AUTH_OPT)) { 
	#QPD->DEBUG("Option: AUTH_OPT"); 
    } 
    if ($control eq num2hex(BINARY)) { 
	#QPD->DEBUG("Option: BINARY"); 
    } 
    if ($control eq num2hex(ECHO)) { 
	#QPD->DEBUG("Option: ECHO"); 
    } 
    if ($control eq num2hex(NEW_ENV)) { 
	#QPD->DEBUG("Option: NEW_ENV"); 
	($code) = $params =~ /^(..)/; 
	if ($code eq num2hex(0x00)) { # IS 
	    #QPD->DEBUG("Received NEW_ENV Is"); 
	} 
	if ($code eq num2hex(0x01)) { # SEND 
	    #QPD->DEBUG("Received NEW_ENV Send"); 
	    print $socket chr(IAC).chr(SB). 
		chr(NEW_ENV). 
		chr(0x00). 
		chr(IAC).chr(SE); 
	    #QPD->DEBUG("Sent NEW_ENV Is"); 
	} 
	if ($code eq num2hex(0x02)) { # INFO 
	    #QPD->DEBUG("Received NEW_ENV Info"); 
	} 
    } 
    if ($control eq num2hex(SUPPRESS_GA)) { 
	#QPD->DEBUG("Option: SUPPRESS_GA"); 
    } 
    if ($control eq num2hex(TERM_SPEED)) { 
	#QPD->DEBUG("Option: TERM_SPEED"); 
    } 
    if ($control eq num2hex(TERM_TYPE)) { 
	#QPD->DEBUG("Option: TERM_TYPE"); 
	($code) = $params =~ /^(..)/; 
	if ($code eq num2hex(0x01)) { # SEND 
	    #QPD->DEBUG("Sending TERM_TYPE"); 
	    print $socket chr(IAC).chr(SB). 
		chr(TERM_TYPE). 
		chr(0x00). 
		chr(0x41).chr(0x4E).chr(0x53).chr(0x49). 
		chr(IAC).chr(SE); 
	    #QPD->DEBUG("Sent TERM_TYPE ANSI"); 
	} 
    } 
    if ($control eq num2hex(WIN_SIZE)) { 
	#QPD->DEBUG("Option: WIN_SIZE"); 
    } 
} 


sub get_csi { 
    my $char = shift; 
    my $params = shift; 

    if (($char eq num2hex(0x48)) || ($char eq num2hex(0x66))) { # H|f 
	#QPD->DEBUG("CSI Cursor Position, params=($params)"); 
	my ($yparam, $xparam) = split qw/;/, $params; 
	$Y = $yparam || 1; 
	$X = $xparam || 1; 
	Ybound; 
	Xbound; 
	$isCSI = 0; 
	$params = ''; 
	return $params; 
    } 

    if ($char eq num2hex(0x41)) { # A 
	#QPD->DEBUG("CSI Cursor Up, params=($params)"); 
	$Y -= $params; 
	Ybound; 
	$isCSI = 0; 
	$params = ''; 
	return $params; 
    } 
    if ($char eq num2hex(0x42)) { # B 
	#QPD->DEBUG("CSI Cursor Down, params=($params)"); 
	$Y += $params; 
	Ybound; 
	$isCSI = 0; 
	$params = ''; 
	return $params; 
    } 
    if ($char eq num2hex(0x43)) { # C 
	#QPD->DEBUG("CSI Cursor Forward, params=($params)"); 
	$X += $params; 
	Xbound; 
	$isCSI = 0; 
	$params = ''; 
	return $params; 
    } 

    if ($char eq num2hex(0x44)) { # D 
	#QPD->DEBUG("CSI Cursor Backward, params=($params)"); 
	$X -= $params; 
	Xbound; 
	$isCSI = 0; 
	$params = ''; 
	return $params; 
    } 
    if ($char eq num2hex(0x72)) { # r 
	#QPD->DEBUG("CSI Scroll Screen, params=($params)"); 
	$xlast = $X; 
	$ylast = $Y; 
	$isCSI = 0; 
	$params = ''; 
	return $params; 
    } 
    if ($char eq num2hex(0x73)) { # s 
	#QPD->DEBUG("CSI Save Cursor Position, params=($params)"); 
	$xlast = $X; 
	$ylast = $Y; 
	$isCSI = 0; 
	$params = ''; 
	return $params; 
    } 
    if ($char eq num2hex(0x75)) { # u 
	#QPD->DEBUG("CSI Restore Cursor Position, params=($params)"); 
	$X = $xlast; 
	$Y = $ylast; 
	$isCSI = 0; 
	$params = ''; 
	return $params; 
    } 
    if ($char eq num2hex(0x4A)) { # J 
	#QPD->DEBUG("CSI Erase Display, params=($params)"); 
	init_term($params); 
	$isCSI = 0; 
	$params = ''; 
	return $params; 
    } 
    if ($char eq num2hex(0x4B)) { # K 
	#QPD->DEBUG("CSI Erase Line, params=($params)"); 
	init_line($params); 
	$isCSI = 0; 
	$params = ''; 
	return $params; 
    } 
    if ($char eq num2hex(0x6D)) { # m 
	#QPD->DEBUG("CSI Graphics Mode, params=($params)"); 
	$isCSI = 0; 
	$params = ''; 
	return $params; 
    } 
    if ($char eq num2hex(0x68)) { # h 
	#QPD->DEBUG("CSI Set Mode, params=($params)"); 
	$isCSI = 0; 
	$params = ''; 
	return $params; 
    } 
    if ($char eq num2hex(0x6C)) { # l 
	#QPD->DEBUG("CSI Reset Mode, params=($params)"); 
	$isCSI = 0; 
	$params = ''; 
	return $params; 
    } 
    if ($char eq num2hex(0x70)) { # p 
	#QPD->DEBUG("CSI Set Keyboard, params=($params)"); 
	$isCSI = 0; 
	$params = ''; 
	return $params; 
    } 
    $params .= chr(hex($char)); 
    return $params; 
} 


sub run_cmdline { 
    my $type = shift; 
    my $cmd = shift; 
    my $preexec = shift; 
    #QPD->DEBUG("type=($type), cmd=($cmd)"); 

    if ($preexec) { 
	($type, $cmd) = &$preexec($type, $cmd); 
	#QPD->DEBUG("Preexec: type=($type), cmd=($cmd)"); 
    } 

    if ($type eq 'CMD') { 
	# Exceptions first 
	if ($cmd eq 'ESCAPE') { 
	    my $packed = pack "C", 0x1B; 
	    print $socket $packed; 
	    print $socket "\r"; 
	    usleep(SEND_DELAY); 
	    return; 
	} 

	if ($cmd eq 'ENTER') { 
	    print $socket "\r"; 
	    usleep(SEND_DELAY); 
	    return; 
	} 
	# Others 
	if ($cmd) { 
	    my @chars = str2chars($cmd); 
	    my $char; 
	    foreach $char (@chars) { 
		print $socket $char; 
		usleep(KEY_DELAY); 
	    } 
	    print $socket "\r"; 
	    usleep(SEND_DELAY); 
	    return; 
	} 
    } 

    if ($type eq 'INMASS') { 
	# Exceptions first 
	if ($cmd eq 'UPARROW') { 
	    my $packed = pack "CCC", 0x1B, 0x5B, 0x41; 
	    print $socket $packed; 
	    usleep(SEND_DELAY); 
	    return; 
	} 
	if ($cmd eq 'DOWNARROW') { 
	    my $packed = pack "CCC", 0x1B, 0x5B, 0x42; 
	    print $socket $packed; 
	    usleep(SEND_DELAY); 
	    return; 
	} 
	if ($cmd eq 'ESCAPE') { 
	    my $packed = pack "C", 0x1B; 
	    print $socket $packed; 
	    usleep(SEND_DELAY); 
	    return; 
	} 
	if ($cmd eq 'ENTER') { 
	    print $socket "\r"; 
	    usleep(SEND_DELAY); 
	    return; 
	} 
	if ($cmd eq 'TAB') { 
	    print $socket "\t"; 
	    usleep(SEND_DELAY); 
	    return; 
	} 

	# Others 
	if ($cmd) { 
	    my @chars = str2chars($cmd); 
	    my $char; 
	    foreach $char (@chars) { 
		print $socket $char; 
		usleep(KEY_DELAY); 
	    } 
	    usleep(SEND_DELAY); 
	    return; 
	} 
    } 
} 


sub sock_session { 
    $PART_NUMBER = shift; 
    $FILE        = shift; 
    $IP          = $script; 

    unlink($FILE) if (-e $FILE); 

    my $buffer; 
    my $option; 
    my $params; 
    my $received; 
    my $char; 
    my $instruction = shift @$IP; 
    my $type = shift @$instruction; 
    my $row = shift @$instruction; 
    my $pattern = shift @$instruction; 
    my $cmd = shift @$instruction; 
    my $preexec = shift @$instruction; 
    my $length; 
    my $read_attempt; 

    print $socket chr(IAC).chr(DO).chr(ECHO). 
	chr(IAC).chr(DO).chr(BINARY). 
	chr(IAC).chr(WILL).chr(BINARY). 
	chr(IAC).chr(WILL).chr(NEW_ENV). 
	chr(IAC).chr(DO).chr(SUPPRESS_GA). 
	chr(IAC).chr(WILL).chr(SUPPRESS_GA). 
	chr(IAC).chr(WILL).chr(WIN_SIZE); 


  SOCKET: while (1) { 
      if ($select->can_read(2)) { 
	  $length = sysread($socket, $buffer, 4096);      # Blocking call 
	  $read_attempt = 0;                              # 4096 to accomodate 80x25 screen (x2) 
	  #QPD->DEBUG("Reading buffer, length=($length)"); # 80x25 = 4000 
	  my $data = unpack "H*", $buffer; 
	  my @chars = $data =~ /(..)/mg; 

	CHAR: while ($char = shift @chars) { 
	    if ($char eq num2hex(IAC)) { 
		$isIAC = 1; 
		next CHAR; 
	    } 
	    if ($isIAC && (($char eq num2hex(WILL)) || ($char eq num2hex(WONT)))) { 
		$isIAC = 0; 
		$isCapability = 1; 
		next CHAR; 
	    } 
	    if ($isIAC && (($char eq num2hex(DO)) || ($char eq num2hex(DONT)))) { 
		$isIAC = 0; 
		$isCommand = 1; 
		next CHAR; 
	    } 
	    if ($isIAC && ($char eq num2hex(SB))) { 
		$isIAC = 0; 
		$isOption = 1; 
		next CHAR; 
	    } 

	    if ($isIAC && ($char eq num2hex(SE))) { 
		get_option($char, $option); 
		$isIAC = 0; 
		$isOption = 0; 
		$option = ''; 
		next CHAR; 
	    } 
	    if ($isCapability) { 
		get_capability($char); 
		$isCapability = 0; 
		next CHAR; 
	    } 
	    if ($isCommand) { 
		get_command($char); 
		$isCommand = 0; 
		next CHAR; 
	    } 
	    if ($isOption) { 
		$option .= $char; 
		next CHAR; 
	    } 


	    if (!$isANSI) { 
		$received .= chr(hex($char)); 
		
		if ($received =~ /login:/) { 
		    print $socket LOGIN(); 
		    #QPD->DEBUG('Sent login'); 
		    $received = ''; 
		    next CHAR; 
		} 
		if ($received =~ /password:/) { 
		    print $socket PASS(); 
		    #QPD->DEBUG('Sent password'); 
		    $received = ''; 
		    next CHAR; 
		} 
	    } 

	    if ($isANSI) { 
		if ($char eq num2hex(0x1B)) { # ESC 
		    $isESC = 1; 
		    next CHAR; 
		} 
		if ($isESC && ($char eq num2hex(0x5B))) { # [ 
		    $isESC = 0; 
		    $isCSI = 1; 
		    next CHAR; 
		} 
		if ($isESC) { # Restore consumed 0x1B? 
		    $isESC = 0; 
		    if ($char eq num2hex(0x44)) { 
			#QPD->DEBUG('Found ESC + D'); 
			next CHAR; 
		    } 
		    if ($char eq num2hex(0x4D)) { 
			#QPD->DEBUG('Found ESC + M'); 
			next CHAR; 
		    } 
		} 
		if ($isCSI) { 
		    $params = get_csi($char, $params); 
		    next CHAR; 
		} 
		if ($char eq num2hex(0x0A)) { # New Line 
		    $Y++; 
		    next CHAR; 
		} 
		if ($char eq num2hex(0x0D)) { # Carriage Return 
		    $X = 1; 
		    next CHAR; 
		} 

		poke_term($char); 
	    } 
	} 
	  #QPD->DEBUG('Finished buffer'); 


	  draw_term; 

	  # Wait for pattern on screen 
	  if ($isANSI && onScreen($pattern, $row)) { 
	      #QPD->DEBUG("X=($X), Y=($Y)"); 

	      run_cmdline($type, $cmd, $preexec); 

	      if ($instruction = shift @$IP) { 
		  $type = shift @$instruction; 
		  $row = shift @$instruction; 
		  $pattern = shift @$instruction; 
		  $cmd = shift @$instruction; 
		  $preexec = shift @$instruction; 
	      } 
	      else { 
		  #QPD->DEBUG('Finished instructions'); 
		  close $socket; 
		  last SOCKET; 
	      } 
	  } 
      } 
      else { 
	  #QPD->DEBUG("Waiting for buffer, attempt=($read_attempt)"); 
	  $read_attempt++; 
      } 

      # Failsafe. No endless loops. 
      if ($read_attempt > MAX_ATTEMPT) { 
	  #QPD->DEBUG('Exceeded max attempts. Terminating.'); 
	  last SOCKET; 
      } 
  } 
    #QPD->DEBUG('Finished Loop'); 
    #draw_term; 

    return $XML; 
} 

init_term; 
sock_session; 
}

1;
__END__

