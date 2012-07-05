#!/usr/bin/perl
package QP::Socket::iCPU;


use strict;
use lib '/var/www/lib';
use QP::Socket::Base;
use Time::HiRes qw(usleep);
use Data::Dumper;
use QP::QPP::Constants;
use QP::QPP::DB::Constants;
use QP::QPP::Debug::Constants;
use QP::MySQL::DBMS;

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

use constant SEND_DELAY  => 500000;
use constant KEY_DELAY   => 100000;
use constant MAX_ATTEMPT => 30;


use constant ADDR        => '10.2.0.101'; #'10.0.21.69';
use constant PORT        => '23';
use constant LOGIN       => "Bobby\r\n"; #"apache\r\n";
use constant PASS        => "windows\r\n"; #"Glavda,\r\n";

use constant FIELDS => 
{ # Hash of permitted instance variables used to automatically
    # handle getting/setting iv values via AUTOLOAD
    addr           => undef, # Address
    dbms           => undef, # DBMS instance,
    dbugr          => undef, # Debugger object,
#    debug          => 0,     # Verbosity of debug messages to print,
    FILE           => undef, 
    IP             => undef, # Script want to run
    isIAC          => 0,
    isCapability   => 0,
    isCommand      => 0,
    isOption       => 0,
    isANSI         => 0,
    isCSI          => 0,
    isESC          => 0,
    PART_NUMBER    => undef,
    port           => undef, # Port
    socket         => undef,
    select         => undef,
    telnet         => undef,
    TERM           => ['','','','','','','','','','','','','','','','','','','','','','','','',''],
    X              => 1,
    xlast          => 1,
    Y              => 1,
    ylast          => 1,
    XML            => undef,
    
};



    sub init_line {
	my $param = shift;
	my $self  = shift;
	my $X     = $self->{X};
	my $Y     = $self->{Y};
	my $TERM  = $self->{TERM};
	my ($row, $col, $diff);
	$col = $X;
	$diff = 80 - $col;

	if ($param eq '') {
	    $row = $TERM->[$Y - 1];
	    substr($row, $col - 1) = '`' x $diff; 
	    $TERM->[$Y - 1] = $row;
	    $self->{TERM} = $TERM;
	    return $TERM;
	}
	if ($param eq '1') {
	    $row = $TERM->[$Y - 1];
	    substr($row, 0, $col - 1) = '`' x $col; 
	    $TERM->[$Y - 1] = $row;
	    $self->{TERM} = $TERM;
	    return $TERM;
	    
	}
	if ($param eq '2') {
	    $TERM->[$Y - 1] = '`' x 80;
	    $self->{TERM} = $TERM;
	    return $TERM;
	}
    } 



sub init_term {
    my $param = shift;
    my $self  = shift;
    my $Y     = $self->{Y};
    my $TERM  = $self->{TERM};
    my $row;
    my $col;
    
    if ($param eq '') {
	for $row ($Y..25) {
	    $TERM->[$row - 1] = '`' x 80;
	}
    }
    if ($param eq '1') {
	for $row (1..$Y) {
	    $TERM->[$row - 1] = '`' x 80;
	    
	}
    }
    if ($param eq '2') {
	for $row (1..25) {
	    $TERM->[$row - 1] = '`' x 80;
	}
    }
    $self->{TERM} = $TERM;
    $TERM;
}


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
    my $X = shift;
    $X = 80 if ($X > 80);
    $X = 1 if ($X < 1);
    $X
}

sub Ybound {
    my $Y = shift;
    $Y = 25 if ($Y > 25);
    $Y = 1 if ($Y < 1);
    $Y
}


sub poke_term {
    my $char = shift;
    my $self = shift;
    my $X    = $self->{X};
    my $Y    = $self->{Y};
    my $TERM = $self->{TERM};
    
    my $row = $TERM->[$Y-1];
    substr($row, $X-1, 1) = chr(hex($char));
    $X++;
    $self->{X} = Xbound($X);
    $TERM->[$Y-1] = $row;
    $self->{TERM} = $TERM;
    $TERM
}

sub draw_term {
    my $self = shift;
    my $TERM = $self->{TERM};
    my ($row, $col);
    for $row (1..25) {
	print $TERM->[$row-1];
	print "\n";
    }
}


sub get_command {
    my $command = shift;
    my $socket  = shift;
    my $self    = shift;
    
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
	$self->{isANSI} = 1;
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


sub get_option {
    my $socket = shift;    
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
    my $char   = shift;
    my $params = shift;
    my $self   = shift;
    my $X      = $self->{X};
    my $xlast  = $self->{xlast};
    my $Y      = $self->{Y};
    my $ylast  = $self->{ylast};
    my $TERM   = $self->{TERM};
    my $isCSI  = 1;
  
    if (($char eq num2hex(0x48)) || ($char eq num2hex(0x66))) { # H|f
	#QPD->DEBUG("CSI Cursor Position, params=($params)");
	my ($yparam, $xparam) = split qw/;/, $params; #change - added qw
	$Y = $yparam || 1;
	$X = $xparam || 1;
	$Y = Ybound($Y);
	$X = Xbound($X);
	$self->{Y} = $Y;
	$self->{X} = $X;
	$isCSI = 0;
	$self->{isCSI} = $isCSI;
	$params = '';
	return $params;
    }
    if ($char eq num2hex(0x41)) { # A
	#QPD->DEBUG("CSI Cursor Up, params=($params)");
	$Y -= $params;
	$Y = Ybound($Y);
	$self->{Y} = $Y;
	$isCSI = 0;
	$self->{isCSI} = $isCSI;
	$params = '';
	return $params;
    }
    if ($char eq num2hex(0x42)) { # B
	#QPD->DEBUG("CSI Cursor Down, params=($params)");
	$Y += $params;
	$Y = Ybound($Y);
	$self->{Y} = $Y;
	$isCSI = 0;
	$self->{isCSI} = $isCSI;
	$params = '';
	return $params;
    }
    if ($char eq num2hex(0x43)) { # C
	#QPD->DEBUG("CSI Cursor Forward, params=($params)");
	$X += $params;
	$X = Xbound($X);
	$self->{X} = $X;
	$isCSI = 0;
	$self->{isCSI} = $isCSI;
	$params = '';
	return $params;
    }
    if ($char eq num2hex(0x44)) { # D
	#QPD->DEBUG("CSI Cursor Backward, params=($params)");
	$X -= $params;
	$X = Xbound($X);
	$self->{X} = $X;
	$isCSI = 0;
	$self->{isCSI} = $isCSI;
	$params = '';
	return $params;
    }
    if ($char eq num2hex(0x72)) { # r
	#QPD->DEBUG("CSI Scroll Screen, params=($params)");
	$xlast = $X;
	$ylast = $Y;
	$self->{xlast} = $xlast;
	$self->{ylast} = $ylast;
	$isCSI = 0;
	$self->{isCSI} = $isCSI;
	$params = '';
	return $params;
    }
    if ($char eq num2hex(0x73)) { # s
	#QPD->DEBUG("CSI Save Cursor Position, params=($params)");
	$xlast = $X;
	$ylast = $Y;
	$self->{xlast} = $xlast;
	$self->{ylast} = $ylast;
	$isCSI = 0;
	$self->{isCSI} = $isCSI;
	$params = '';
	return $params;
    }
    if ($char eq num2hex(0x75)) { # u
	#QPD->DEBUG("CSI Restore Cursor Position, params=($params)");
	$X = $xlast;
	$Y = $ylast;
	$self->{Y} = $Y;
	$self->{X} = $X;
	$isCSI = 0;
	$self->{isCSI} = $isCSI;
	$params = '';
	return $params;
    }
    if ($char eq num2hex(0x4A)) { # J
	#QPD->DEBUG("CSI Erase Display, params=($params)");
	$TERM = init_term($params);
	$isCSI = 0;
	$self->{isCSI} = $isCSI;
	$params = '';
	return $params;
    }
    if ($char eq num2hex(0x4B)) { # K
	#QPD->DEBUG("CSI Erase Line, params=($params)");
	$TERM = init_line($params, $self);
	$isCSI = 0;
	$self->{isCSI} = $isCSI;
	$params = '';
	return $params;
    }
    if ($char eq num2hex(0x6D)) { # m
	#QPD->DEBUG("CSI Graphics Mode, params=($params)");
	$isCSI = 0;
	$self->{isCSI} = $isCSI;
	$params = '';
	return $params;
    }
    if ($char eq num2hex(0x68)) { # h
	#QPD->DEBUG("CSI Set Mode, params=($params)");
	$isCSI = 0;
	$self->{isCSI} = $isCSI;
	$params = '';
	return $params;
    }
    if ($char eq num2hex(0x6C)) { # l
	#QPD->DEBUG("CSI Reset Mode, params=($params)");
	$isCSI = 0;
	$self->{isCSI} = $isCSI;
	$params = '';
	return $params;
    }
    if ($char eq num2hex(0x70)) { # p
	#QPD->DEBUG("CSI Set Keyboard, params=($params)");
	$isCSI = 0;
	$self->{isCSI} = $isCSI;
	$params = '';
	return $params;
    }
    $self->{isCSI} = $isCSI;
    $params .= chr(hex($char));
    return $params;
}

sub run_cmdline {
    my $socket  = shift;
    my $type    = shift;
    my $cmd     = shift;
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


    sub onScreen {
	my $pattern = shift || return 0;
	my $row     = shift;
	my $TERM    = shift;
	my $Y       = shift;
	
	if ($row eq 'PROMPT') {
	    $row = $Y;
	}

	my $ubound = $row || 25;
	my $lbound = $row || 1;
	my $i;
	for $i ($lbound..$ubound) {
	    my $line = join '', $TERM->[$i - 1];
	    if ($line =~ /$pattern/) {
		#QPD->DEBUG("Pattern=($pattern) found at row=($row), ubound=($ubound), lbound=($lbound)");
		return 1;
	    }
	}
	return 0;
    }



# *****************************************************************************
# *****************************************************************************
#			       Methods
# *****************************************************************************
# *****************************************************************************

our ( @ISA, $DEBUG );

# Create a new iCPU object
#------
sub new  {
#------
    my $type     = shift;
    my $class    = ref($type) || $type;
    my $defaults = { @_ };
    my $self;

    if (ref($type))
    { # $type is actually an object, freshen it up according to my tastes
	$self = $type;
    }
    else
    { # Create object from a fresh
	$self = {
	    _permitted => {},
	};
	bless $self, $class;
    }

    foreach my $key (keys %{&FIELDS})
    { # Populate object with instance variables defined in this class
	my $value;
	if (defined $defaults->{$key})
	{ # Most desired value is from object's defaults
	    $value = $defaults->{$key};
	}
	elsif (defined $self->FIELDS->{$key})
	{ # Less desirable value is from self
	    $value = $self->FIELDS->{$key}
	}
	else
	{ # Least desired value is from object's package
	    $value = FIELDS->{$key};
	}

	$value = &Storable::dclone($value)
	    if $key !~ /^(headerfields|detailfields|var)$/i and
	    ((ref($value) eq 'HASH') or (ref($value) eq 'ARRAY'));
	$self->{_permitted}->{$key} = $value;
	$self->{$key}               = $value;
    }

    my %seen;
    foreach my $super (@ISA)
    {
	if (my $code = $super->can('new')) 
	{ # Invoke super's new method only once
	    $self->$code(@_)  unless $seen{$code}++;
	}
    }
    
    $self;
}


#------
sub dpr  {
#------
    my $level  = shift;		# Debug level
    my $ctlstr = shift;

    printf( $ctlstr, @_ )  if defined($main::DEBUG) and $level <= $main::DEBUG;
}



#----------
sub cleanup  {
#----------
    my $self = shift;

    dpr(70, "QP::QPP::Excel::Parser::cleanup\n");

    # Call inherited cleanup methods just once
    my %seen;
    foreach my $super (@ISA)
    {
	if (my $code = $super->can('cleanup')) 
	{ # Invoke super's DESTROY method only once
	    $self->$code(@_)  unless $seen{$code}++;
	}
    }

    $self->{var}   = undef;
    $self->{dbms}  = undef;
    $self->{dbugr} = undef;

}

#----------
sub DESTROY  {
#----------
    my $self = shift;

    $self->cleanup();
}

#-----------
sub AUTOLOAD  {
#-----------
    our $AUTOLOAD;
    my $self = shift;
    my $name = $AUTOLOAD;
    my $type = ref($self) or die "$self is not an object, method $name";

    $name =~ s/.*://;           # strip fully-qualified portion

    return if $name eq 'DESTROY';

    die sprintf("Can't access '%s' field in class %s from (%s), line (%d)",
                $name, $type, (caller())[1], (caller())[2])
        if !exists $self->{_permitted}->{$name};

    my $value      = $self->{$name};
    $self->{$name} = shift  if (@_);
    $value;
}




#Paramters({addr, port, emptyhash_for_instance_info})
#-----------
sub open  { 
#-----------
#------------------PARAMETERS_________________

    my $self       = shift;
    my $addr       = shift;
    my $port       = shift;

    $self->{addr}  = $addr;
    $self->{port}  = $port?$port:23;
    $port = $self->{port};

    $|=1;

    $self->{telnet}  = QP::Socket::Base->new($addr, $port);
    my $telnet       = $self->{telnet};  
    $self->{socket}  = $telnet->socket;
    my $socket       = $self->{socket};
    $self->{select}  = $telnet->select;
    my $TERM         = $self->{TERM};
    my $X            = $self->{X}; 
    my $Y            = $self->{Y}; 
    my $xlast        = $self->{xlast};
    my $ylast        = $self->{ylast};

    $TERM = init_term('', $self);

    print $socket chr(IAC).chr(DO).chr(ECHO).
	chr(IAC).chr(DO).chr(BINARY).
	chr(IAC).chr(WILL).chr(BINARY).
	chr(IAC).chr(WILL).chr(NEW_ENV).
	chr(IAC).chr(DO).chr(SUPPRESS_GA).
	chr(IAC).chr(WILL).chr(SUPPRESS_GA).
	chr(IAC).chr(WILL).chr(WIN_SIZE);




#    $TERM =  poke_term('61', $self); # 0x61 = a
#    $X    =  $self->{X};
#    $TERM =  init_line('2', $self);
}

#Parameters(timeout) 
#-----------
sub read  {
#-----------
    my $self          = shift;
    my $timeout       = shift;
    my $maxiterations = shift;
    my $minweight     = shift;
    my $pattern       = shift;
    my $row           = '';

    my $select        = $self->{select};
    my $socket        = $self->{socket};
    my $buffer;
    my $option;
    my $params;
    my $received;
    my $char;
    my ($length, $position);
    my $read_attempt;
    my $TERM         = $self->{TERM};
    my $X            = $self->{X};
    my $Y            = $self->{Y};
    my $xlast        = $self->{xlast};
    my $ylast        = $self->{ylast};
    my $isIAC        = 0;
    my $isCapability = 0;
    my $isCommand    = 0;
    my $isOption     = 0;
    my $isANSI       = $self->{isANSI};
    my $isCSI        = 0;
    my $isESC        = 0;
    my $i            = 0;
    my $XML;


  SOCKET: while (1) {
      printf "%d: looping in SOCKET\n", $i++;
      if ($select->can_read($timeout)) {
	  $length       = sysread($socket, $buffer, 4096);      # Blocking call
	 # $position     = sysseek($socket, 0, 1);
	  $read_attempt = 0;                              # 4096 to accomodate 80x25 screen (x2)
	  #QPD->DEBUG("Reading buffer, length=($length)"); # 80x25 = 4000
	  my $data      = unpack "H*", $buffer;
	  my @chars     = $data =~ /(..)/mg;

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
		get_option($socket, $char, $option);
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
		get_command($char, $socket, $self);
		$isANSI = $self->{isANSI}?$self->{isANSI}:$isANSI;
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
		    $params = get_csi($char, $params, $self);
		    $isCSI = $self->{isCSI};
		    $X     = $self->{X};
		    $Y     = $self->{Y};
		    $xlast = $self->{xlast};
		    $ylast = $self->{ylast};
		    next CHAR;
		}
		if ($char eq num2hex(0x0A)) { # New Line
		    $Y++;
		    $self->{Y} = $Y;
		    next CHAR;
		}
		if ($char eq num2hex(0x0D)) { # Carriage Return
		    $X = 1;
		    $self->{X} = $X;
		    next CHAR;
		}
		
		$self->{TERM} = poke_term($char, $self);
		$X = $self->{X};
	    }
	}
	  #QPD->DEBUG('Finished buffer');
	  
	  $self->draw_term();
	  
	  
	  # Wait for pattern on screen
	  if ($isANSI && onScreen($pattern, $row, $TERM, $Y)) {
	      #QPD->DEBUG("X=($X), Y=($Y)");
	      
	      last SOCKET;
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




#Parameters
#Takes in self, instruction
# Format of Instruction = [Category, Pattern, Row, Command, Pre-exec]
#   Category : Currently only CMD or INMASS
#   Row      : Row to search
#   Pattern  : Regex to match
#   Command  : DOS/INMASS Command to exec if match
#   Pre-exec : Optional. Reference to Perl function to exec before DOS/INMASS Command.
#              Useful for gathering results from previous Command.

#-----------
sub write {
#-----------

    my $self = shift;
    my $instruction = shift;

    my $socket = $self->{socket};
    my $buffer;
    my $option;
    my $params;
    my $received;
    my $char;
    my $type = shift @$instruction;
    my $row = shift @$instruction;
    my $pattern = shift @$instruction;
    my $cmd = shift @$instruction;
    my $preexec = shift @$instruction;
    my $length;
    my $read_attempt = 0;

    run_cmdline($socket, $type, $cmd, $preexec); 
}
#-----------
sub close  {
#-----------
    my $self = shift;
    my $socket = $self->{socket} ;
    close $socket;
    
}
#-----------
sub match  {
#-----------
}
#-----------
sub chnge_timeout  {
#-----------
}

my $self = QP::Socket::iCPU->new();
$self->open(ADDR(), PORT());

my $BASIC_TEST = [
        ['CMD', 'PROMPT', 'C:.+>', 'dir'],
        ['CMD', 'PROMPT', 'C:.+>', 'exit'],
    ];
my $instruction = $BASIC_TEST;

$self->read(2, 5, 2, 'C:.+>');
$self->write(@$instruction[0]);
$self->read(2, 5, 2, 'C:.+>');
$self->write(@$instruction[1]);
$self->close();
