#! /usr/bin/perl
# vim:ts=4:sw=4:ai:et:si:sts=4

use strict;
use warnings;

use Time::HiRes qw(usleep);

my $timeout = 500000;  # .5s delay after changing

my $device  = "/dev/ttyUSB-" . shift;
my $type    = shift;
my $channel = shift;
my $command = "/usr/local/bin/directv.pl port $device box_type $type retries 10";

my $retval;
my $tuned;

sub get_my_channel
{
    my $command = shift;

    # Check what channel we are on
    open( CHANNEL, "-|", "$command get_channel" );
    my $tuned = <CHANNEL>;
    close CHANNEL;

    chomp $tuned;
    $tuned =~ s/channel\s*//;

    return $tuned;
}

# Set the channel
$retval = system( "$command setup_channel $channel" );
usleep $timeout;
if ($retval ne 0)
{
    $tuned = get_my_channel( $command );
    print "retrying via $tuned\n";
    $retval = system( "$command setup_channel $tuned" );
    usleep $timeout;
    if ($retval eq 0)
    {
        $retval = system( "$command setup_channel $channel" );
        usleep $timeout;
    }
}
die "Channel change failure\n\n" if $retval ne 0;

$tuned = get_my_channel( $command );

# Return
#print "$tuned / $channel\n";
exit 0 if $tuned eq $channel;

print "screw this, rebooting the receiver!\n";
system( "$command reboot" );
exit 1;
