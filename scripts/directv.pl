#!/usr/bin/perl
#
# Copyright (c) 2009 Josh Wilmes,  Dave Manaloto, John Gruenenfelder,
# David Gesswein
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# directv.pl:  Remote control of a DirecTV unit via the serial port
# By Josh Wilmes (http://www.hitchhiker.org/dss)
# Based on info from http://www.isd.net/mevenmo/audiovideo.html
#
# I take no responsibility for any damage this script might cause.  
# Feel free to modify and redistribute this as you see fit, but please retain
# the comments above.

# Home site for this version http://www.pdp8online.com/directv/directv.shtml
# See home site, usage command or run without and parameters for how to use
# Documentation of box protocol and cables at 
# http://www.dtvcontrol.com/ and 
# http://www.knoppmythwiki.org/index.php?page=DtenSerialControlScript

# Modified by Dave Manaloto < dave@practicecode.com >
# - Put discrete code to turn on IRD
# - Try and clear OSD after changing channel
# - sync computer to IRD time "--sync-time" (Now set_system_datetime)

# Modified by John Gruenenfelder < johng@as.arizona.edu >
# - Use codes for newer RCA model receivers (same as Sony codes?)
#   Info from http://www.dar.net/~andy/tivo/rca_dss_serial.html
# - Use Perl's select function to pause 0.20 seconds rather than external
#   usleep call
# - Use 9600 baud rate instead of 115200
# 
#  Originally posted to KnoppMythWiki by Bret Shroyer <bret  <at>  bretshroyer ,dot, org> Dec 16, 2004
#
# Modified by David Gesswein < djg@pdp8online.com > June 22, 2005
# Added codes for Directv D10-200 receiver and D10-100 firmware 0x101B
# Added many commands and tried to make flexible enough that users won't
# have to edit this file
# Added retry on errors since the D10-200 is not reliable
# Version 1.1: Fixed to work with D10-100 new firmware
# Version 1.2: Put URL for home page in and other comment changes
# Version 1.3: Added binmode for serial port to prevent problems under windows.
# Version 1.4: Made setup_channel retry if didn't switch to correct channel
# Version 1.5: Added old RCA command codes used by RCA Model DRD420RE,
#              DRD480RE and DRD505RB
# Version 1.6: Fixed bugs in old RCA codes and added more keycodes.
#              Based on modifications by 
#              John Innis < myth_master.9.jdinnis@spamgourmet.com >
#              which used codes from DirecTC Control.exe sourced from 
#              http://www.dtvcontrol.com 
#     The following commands, supported by the RCA serial protocol are missing
#     Command         Old Hex     New Hex
#     ----------------------------------
#     -Cold Boot      0A           None
#     -Warm Boot      0B           None
#     -Enable IR      13           93
#     -Disable IR     14           94
#
# Version 1.7: Modified by William Thomas <wthomas@wstsoft.com> April 14, 2007
#    Added option for D11 receiver and commands for reboot and show.
#    Added serial port code for baudrate 115200 and 57600 (without constants
#    in perl's POSIX code). 57600 and above will likely only work with Linux
#
# Version 1.8 Modified by Tom Hohensee <tomhoh@mac.com> May 25, 2007
#	Added support for H20 reciever (which is same keymap as the D10-100) 
#       it also required Baud rate=115200.
#	Added support for Mac OS X baud rate >38400
#	For H20 and D11 -Mac OS X a usb to serial adapter at both ends works.
#
# Version 1.9 Added setup_channel_sd_hd

$|=1;
use POSIX qw(:termios_h);
use Time::HiRes qw(usleep ualarm gettimeofday tv_interval );

use FileHandle;

$version = "1.9";

#
# Verbose output, change with verbose and quiet command.
#
$verbose=0;

#
# Error Retries, change with retry command.
#
$retry_count=4;

# set baudrate for appropriate box -9600 for D10, -115200 or 9600 for D11
#  depending on firmware version, 115200 for H20
$baudrate = "9600";
				  
#
# Serial port settings.  Change to suit.  Baudrate probably doesn't need to be
# changed.  Set port with port command.
# for Mac OS X (usb to serial adapter required) port will start with cu 
# (eg /dev/cu.KeySerial1)
$serport = "/dev/ttyS0";

#
# Box type, set with box_type command
# 
$box_type = "RCA";

#
# Delay to wait after channel change before turning off OSD in setup_channel
# command.  Can use separate commands with delay command to control delay.
#
$clear_osd_delay = .2;
#
# Delay to wait after channel change before querying signal strength
#
$sd_hd_signal_delay = .2;

#perl's implementation of POSIX doesn't have B57600 (or higher)
#This table handles it for the particual os ($^O)
%baud_map =("linux57600" => 0010001,
            "linux115200" => 0010002,
            "darwin57600" => 57600,
            "darwin115200" => 115200);

%pkt_decode=("0xF0" => "START PKT",
             "0xF1" => "ERR 1",
             "0xF2" => "GOT EXTENDED",
             "0xF4" => "END PKT",
             "0xF5" => "ERR 2",
             "0xFB" => "PROMPT");

# -1 is command had error, 1 is command completed ok
%terminal=("0xF1" => -1,
           "0xF4" => 1,
           "0xF5" => -1);

# Map commands to function to execute.
# last_param is handled in main routine.
#      "show" => \&show,  Doesn't seem to be in new command set
#      "scroll" => \&scroll,   
%cmds=("on" => \&on,
      "off" => \&off,
      "reboot" => \&reboot,
      "text" => \&text,
      "show" => \&show,
      "hide" => \&hide,
      "get_channel" => \&get_channel,
      "get_signal" => \&get_signal,
      "get_datetime" => \&get_datetime,
      "set_system_datetime" => \&set_system_datetime,
      "key" => \&key,
      "delay" => \&delay,
      "port" => \&port,
      "baudrate" => \&baudrate,
      "box_type" => \&box_type,
      "retries" => \&retries,
      "channel_change_type" => \&channel_change_type,
      "setup_channel" => \&setup_channel,
      "setup_channel_sd_hd" => \&setup_channel_sd_hd,
      "version" => \&version,
      "verbose" => \&set_verbose,
      "quiet" => \&clear_verbose
      );

# Key to keycode map for most boxes
%keymap=(right => "0xa8",
          left => "0xa9",
            up => "0xa6",
          down => "0xa7",
      favorite => "0x9e",
        select => "0xc3",
         enter => "0xc3",  # Doesn't have separate enter?
          exit => "0xc5",
             9 => "0xc6",
             8 => "0xc7",
             7 => "0xc8",
             6 => "0xc9",
             5 => "0xca",
             4 => "0xcb",
             3 => "0xcc",
             2 => "0xcd",
             1 => "0xce",
             0 => "0xcf",         
         ch_up => "0xd2",
         ch_dn => "0xd3",
         power => "0xd5",
          jump => "0xd8",
         guide => "0xe5",
          menu => "0xf7",
         clear => "0xf9",
       antenna => "0xfa",
          play => "0xea",
        record => "0xe8",
         pause => "0xe6",
       forward => "0xe3",
       reverse => "0xe2",
          stop => "0xe0",
           dss => "0xc5",
           off => "0xc4",
          skip => "0xac",
     alt_audio => "0x4f");


# Key to keycode map for Directv D10-200 and D10-100 firmware 0x101B
%keymap_200 =
        (right => "0x9a",
          left => "0x9b",
            up => "0x9c",
          down => "0x9d",
        select => "0xc3",
         enter => "0xa0", 
          exit => "0xd4",
             9 => "0xe9",
             8 => "0xe8",
             7 => "0xe7",
             6 => "0xe6",
             5 => "0xe5",
             4 => "0xe4",
             3 => "0xe3",
             2 => "0xe2",
             1 => "0xe1",
             0 => "0xe0",         
          dash => "0xa5",         
           "-" => "0xa5",         
         ch_up => "0xd1",
         ch_dn => "0xd2",
         power => "0xd5",
          jump => "0xd6",   # Name from other set
          prev => "0xd6",   # Key label on -200
         guide => "0xd3",
          menu => "0xf7",
          info => "0xa1",
        active => "0xa2",
          list => "0xa3",
          back => "0xa4"
# Code B0 are accepted by box but I couldn't figure out what if
# anything they do.
);

# From box name select correct key codes
%boxes=("RCA" => \%keymap,
        "RCA_OLD" => \%keymap,
        "D10-100" => \%keymap_200,
        "D10-200" => \%keymap_200, 
	"D11"     => \%keymap_200,
	"H20"     => \%keymap_200,
); 

# From box name select extra bytes needed with key codes
%keymap_extra=("RCA" => ["0x00", "0x00"],
           "RCA_OLD" => ["0x00", "0x00"],
           "D10-100" => ["0x00", "0x01"],
           "D10-200" => ["0x00", "0x01"],
	   "D11"     => ["0x00", "0x01"],
	   "H20"     => ["0x00", "0x01"],
); 

# From box name select extra bytes needed after sending command
%cmd_extra=("RCA" => undef,
           "RCA_OLD" => undef,
           "D10-100" => undef, 
           "D10-200" => "0x0d",
	   "D11" => "0x00",
	   "H20" => undef
); 

# From box name select if we should use the channel change command
# or send remote keys.  The D10-200 locks up randomly with the channel
# change command and the D10-100 firmware 0x101B won't select below 100.
%chan_change_key=("RCA" => 0,
                  "RCA_OLD" => 0,
                  "D10-100" => 1,
                  "D10-200" => 1,
		  "D11" => 1,
		  "H20" => 1
); 
# Override from command line for above
my $chan_change_key_param;


my $serial;
my $i;

# Replace argument last_param with last parameter on the command line.
# The last parameter is then removed.
for ($i = 0; $i < $#ARGV; $i++) {
   if ($ARGV[$i] eq "last_param") {
      $ARGV[$i] = $ARGV[$#ARGV];
      $#ARGV = $#ARGV - 1;
      last;
   }
}

if ($#ARGV < 0) {
   usage();
}

while ($#ARGV >= 0) {
   if (defined($sub = $cmds{$ARGV[0]})) {
      shift @ARGV;
      &$sub;
   } else {
      if ($ARGV[0] == 0) {
         usage();
         die "\nCommand $ARGV[0] not found\n"
      }
      change_channel($ARGV[0]); 
      shift @ARGV;
   }
}

exit(0);

sub usage {
   print "Usage: $0 command ...\n";
   print "Commands:\n";
   print "  box_type RCA|RCA_OLD|D10-100|D10-200|D11|H20  - select set top box type\n";
   print "  delay number    - wait for number seconds. Floating point is valid \n";
   print "  key string      - send remote key string.  See source for supported keys\n";
   print "  last_param      - execute last parameter on command line at current location\n";
   print "  number{-number} - change to specified channel-subchannel\n";
   print "  off             - turn box off\n";
   print "  on              - turn box on\n";
   print "  reboot          - hard reboot (reset)\n";
   print "  port string     - select port to send commands on, currently $serport\n";
   print "                    should be first on command line\n";
   print "  setup_channel number - send on, channel change command and OSD off command\n";
   print "                         retries if channel change not sucessful\n";
   print "  setup_channel_sd_hd number - setup_channel for SD only service with HD box\n";
   print "                         Use when you need channel up see SD channel when HD exists\n";
   print "  version         - display program version\n";
   print "\n";
   print "  baudrate number      - select serial port baudrate, currently $baudrate\n";
   print "  channel_change_type key|command - select channel change method\n";
   print "  get_channel          - print current channel\n";
   print "  get_datetime         - print date and time\n";
   print "  get_signal           - print signal strength\n";
   print "  hide                 - hide text, will also prevent info button from working\n";
   print "  show                 - show text, will also allow info button to work\n";
   print "  retries number       - set maximum number of retries on error\n";
   print "  set_system_datetime  - set PC clock from box.  ntp is more accurate\n";
   print "  text string          - display string on screen, \"\" to clear\n";
   print "  verbose|quiet        - select how much information printed\n";
   print "\n";
   print "Mythtv command for normal RCA box: directv.pl setup_channel\n";
   print "Complex Mythtv command for D10-200 box doing same as setup_channel:\n";
   print "   directv.pl box_type D10-200 on last_param delay .2 key exit\n";
   print "Mythtv adds channel number at end of command\n";
}

sub setup_channel {
   my $tries = $retry_count;
   my $cmd_chan = shift(@ARGV);
   my @in, $sub, $chan;
   while ($tries-- > 0) {
      on();
      change_channel($cmd_chan); 
      select(undef, undef, undef, $clear_osd_delay);
      send_key("exit");
      $chan = get_channel_str();
      last if ($cmd_chan eq $chan);
   }
   die "Excessive channel change retries, commanded $cmd_chan got $chan\n" if $tries < 0;
}

sub setup_channel_sd_hd {
   my $tries = $retry_count;
   my $cmd_chan = shift(@ARGV);
   my @in, $sub, $chan;
   while ($tries-- > 0) {
      on();
      change_channel($cmd_chan); 
      select(undef, undef, undef, $clear_osd_delay);
      send_key("exit");
      $chan = get_channel_str();
      if ($cmd_chan eq $chan) {
         select(undef, undef, undef, $sd_hd_signal_delay);
         $sig = get_signal_str();
         if ($sig == 0) {
            send_key("ch_up");
         }
         last;
      }
   }
   die "Excessive channel change retries, commanded $cmd_chan got $chan\n" if $tries < 0;
}

sub version {
   print "Version $version\n"; 
}

sub retries {
   $retry_count = shift(@ARGV); 
}

sub channel_change_type {
   my $type = shift(@ARGV); 
   if ($type eq "key") {
      $chan_change_key_param = 1;
   } elsif ($type eq "command") {
      $chan_change_key_param = 0;
   } else {
      die "Unkown channel_change_type $type\n";
   }
}

sub key {
   send_key(shift(@ARGV));
}

sub send_key {
   my $map = $boxes{$box_type};
   my $key = $$map{shift(@_)};
   die "Unknown key $ARGV[0]\n" if (!defined($key));
   simple_command(map_code("0xA5"),@{$keymap_extra{$box_type}}, "0x$key");
}

sub box_type {
   my ($tmp) = uc(shift(@ARGV));
   die "Unknown box_type $tmp\n" if (!defined($boxes{$tmp}));
   $box_type = $tmp;
}

sub port {
   $serport = $ARGV[0];
   shift @ARGV;
}

sub baudrate {
   $baudrate = $ARGV[0];
   shift @ARGV;
}

sub delay {
   select(undef, undef, undef, $ARGV[0]);
   shift @ARGV;
}

sub set_verbose {
   $verbose = 1;
}

sub clear_verbose {
   $verbose = 0;
}

sub on {
  simple_command(map_code("0x82"));
}

sub off {
  simple_command(map_code("0x81"));
}

sub reboot {
  #Have to use sendbytes - reboot doesn't wait to reply
  sendbytes("0xFA","0x96");
}

sub get_channel_str {
  my $chan;
  if ($box_type eq "RCA_OLD") {
     my @in = dss_command(2, map_code("0x87"));
     return undef if($#in != 1);
     $chan =  $in[0]*256+$in[1];
  } else {
     my @in = dss_command(4, map_code("0x87"));
     return undef if($#in != 3);
     my $sub = $in[2] * 256 + $in[3];
     $chan =  $in[0]*256+$in[1];
     $chan =  $chan . "-$sub" if $sub != 65535;
  }
  return $chan;
}

sub get_channel {
   my $channel = get_channel_str();
   if (defined($channel)) {
      print "channel " . $channel . "\n";
   }
}


sub get_signal_str {
  my @in = dss_command(1, map_code("0x90"));
  return undef if($#in != 0);
  return $in[0];
}

sub get_signal {
  my $signal = get_signal_str();
  if (defined($signal)) {
     print "signal $signal\n";
  }
}

sub get_datetime {
    my @in = dss_command(7, map_code("0x91"));
    return if($#in != 6);
    $strTime = "$in[1]/$in[2] $in[3]:$in[4]:$in[5]";
    print("Date $strTime\n")# if ($verbose);
}

sub set_system_datetime {
    my @in = dss_command(7, map_code("0x91"));
    return if($#in != 6);
    my $strTime = "$in[1]/$in[2] $in[3]:$in[4]:$in[5]";
    print("Setting system time to $strTime\n") if ($verbose);
    $cmd = "echo date -s \"$strTime\"";
    `$cmd`;
}

sub text {
  my @tmp = unpack("H2" x length($ARGV[0]) ,$ARGV[0]);
  shift @ARGV;
  simple_command(map_code("0xaa"), sprintf("%x",$#tmp+1), @tmp);
}

sub hide {
  simple_command(map_code("0x86"));
}

sub show {
  simple_command(map_code("0x85"));
}

sub simple_command {
    if (defined(dss_command(0, @_))) {
        return(1);
    } else {
        return(undef);
    }
}


sub dss_command {
    my $reply_size = shift(@_);
    for (my $i = 0; $i < $retry_count; $i++) {
       sendbytes("0xFA",@_);
       my $rc = get_reply($reply_size);
       if (defined($rc)) {
          return @{$rc};
       }
       # Clear any extra junk received on error
       sysread($serial,$buf,100);
       #print STDERR "Retry " , scalar localtime(time()) , "\n";
    }
    die "Error excessive retries\n";
} 

# Send channel change command or remote key pushes to change channel
sub change_channel { 
   my $change_key;
   if (defined($chan_change_key_param)) {
      $change_key = $chan_change_key_param;
   } else {
      $change_key = $chan_change_key{$box_type};
   }
   if ($change_key) {
      foreach $ch (split //,@_[0]) {
         send_key($ch);
      }
      send_key("enter");
   } else {

       my ($channel,$sub)= split /-/,@_[0];
       my $s1,$s2,$n1,$n2;
       $_=sprintf("%4.4x",$channel);
       ($n1,$n2)=/(..)(..)/;
       if (defined($sub)) {
          $_=sprintf("%4.4x",$sub);
          ($s1,$s2)=/(..)(..)/;
       } else {
          $s1 = "0xff";
          $s2 = "0xff";
       }
       simple_command(map_code("0xA6"),$n1,$n2,$s1,$s2);
   }
}


sub sendbytes {
    my (@send)=@_;
    my $fullstr = "";
    if (!$serial) {
       $serial=init_serial($serport,$baudrate);
    }
    if (defined($cmd_extra{$box_type})) {
       push @send,$cmd_extra{$box_type};
    }
    foreach (@send) { s/^0x//g; $_=hex($_); }
    print "SEND: " if ($verbose);
    foreach $num (@send) {
        $str = pack('C',$num);
        $fullstr = $fullstr . $str;
        printf("0x%X [%s] ", $num, $str) if ($verbose);
    }
    syswrite($serial,$fullstr,length($fullstr));
    print "\n" if ($verbose);
}

sub map_code() {
   my ($key) = (@_);
   if ($box_type eq "RCA_OLD") {
      if ($key ge "0xA0") {
         $key = "0x4" . substr($key,3,1);
      } elsif ($key ge "0x90") {
         $key = "0x1" . substr($key,3,1);
      } else {
         $key = "0x0" . substr($key,3,1);
      }
   }
   return $key;
}

# Get reply back.  Reply should start with F0 then reply size bytes which
# are passed back without examination then look for error or ok status.
# Pass back any other bytes not part of status also.
sub get_reply() {
    my ($reply_size) = @_;
    #my $starttime=time();
    my $starttime=[gettimeofday];
    my $found_start = 0;
    my ($last,$ok,@ret,$rc);
    @ret=();

    print "RECV: " if ($verbose);

    while (1) {       
       $rc=sysread($serial,$buf,1);
       if ($rc < 0) {
          print STDERR "Read Error ($rc)\n" if ($verbose);
          last;
       }
       if ($rc == 0) {
          if (tv_interval($starttime) > .8) {
          #if (time() - ($starttime) > 2) {
             print STDERR "Timeout Error\n" if ($verbose);
             last;
          }
          next;
       }
          
       $str=sprintf("0x%2.2X", ord($buf));       

       if ((!$found_start || $reply_size <= 0) && $pkt_decode{$str}) {
           print $str if ($verbose);
           print "[$pkt_decode{$str}] " if ($verbose);
       } else {
           $_=$str; s/^0x//g; $_=hex($_);  
           printf("$str(%3.3s) ",$_) if ($verbose);
           push (@ret,$_); 
       }
       
       if ($found_start && $reply_size-- <= 0) {
          $ok=1 if ($terminal{$str} > 0);
          last if ($terminal{$str});
          last if ($last eq "0xFB" && $str eq "0xFB");
       }
       $found_start = 1 if ($str eq "0xF0");
       $last=$str;
   }
   print "\n\n" if ($verbose);

   return \@ret if ($ok);
   return undef;
}


sub init_serial {
    my($port,$baud)=@_;
    my($termios,$cflag,$lflag,$iflag,$oflag);
    my($voice);
 
    my $serial=new FileHandle("+>$port") || die "Could not open $port: $!\n";
    
    binmode($serial);

    $termios = POSIX::Termios->new();
    $termios->getattr($serial->fileno()) || die "getattr: $!\n";
    $cflag= 0 | CS8 | HUPCL | CREAD | CLOCAL;
    $lflag= 0;
    $iflag= 0 | IGNBRK | IGNPAR;
    $oflag= 0;
        
    $termios->setcflag($cflag);
    $termios->setlflag($lflag);
    $termios->setiflag($iflag);
    $termios->setoflag($oflag);
    $termios->setattr($serial->fileno(),TCSANOW) || die "setattr: $!\n";
	
    #perl's implementation of POSIX doesn't have B57600 (or higher)
    #This table handles it for the particual os
    my $special_baud = $baud_map{$^O.$baud};
    if (defined($special_baud)) {
        $termios->setospeed($special_baud) || die "setospeed($baud): $!\n";
        $termios->setispeed($special_baud) || die "setispeed($baud): $!\n";
    }
    else
    {
			eval qq[
			\$termios->setospeed(POSIX::B$baud) || die "setospeed: $!\n";
			\$termios->setispeed(POSIX::B$baud) || die "setispeed: $!\n";
				   ];
			die $@ if $@;
    }
    $termios->setattr($serial->fileno(),TCSANOW) || die "setattr: $!\n";

    # Make reads wait up to 200ms for a character
    $termios->getattr($serial->fileno()) || die "getattr: $!\n";        
    $termios->setcc(VMIN,0);
    $termios->setcc(VTIME,2);
    $termios->setattr($serial->fileno(),TCSANOW) || die "setattr: $!\n";
    
    return $serial;
}
