#! /usr/bin/perl

use warnings;
use strict;

# Adjust this to $PREFIX/share/perl/5.10.1 (or whatever perl version)
use lib '/opt/mythtv/master/share/perl/5.10.1';

use MythTV;

# Fill in this hash with cardid => serial number for each HDPVR, power device
# pair.  If a zero-byte file is detected from any device in here, its power 
# will be turned off for 15s, then back on
my %hdpvrs = ( 32 => "GHUCYEL8" );

my $Myth = new MythTV();

# $0 cardid chanid starttime
my ($cardid, $chanid, $starttime, $cancel) = @ARGV;

die "You must provide cardid, chanid, starttime!\n"
   if (!$cardid || !$chanid || !$starttime);

my $recording = undef;
my $delay = 30;
my $runningfile = "/tmp/$cardid-$chanid-$starttime.running";
my $cancelfile  = "/tmp/$cardid-$chanid-$starttime.cancel";

if ((defined $cancel) && ($cancel eq "cancel") && (-f $runningfile))
{
    touch($cancelfile);
    exit 0;
}

touch($runningfile);

# Give the HDPVR time to start capturing
my $count = 0;
while ($count < 20) {
    cancel() if (-f $cancelfile);
    $count++;
    sleep 1;
}

while ((!$recording || !(exists $recording->{'local_path'}) || 
        !(-f $recording->{'local_path'})) && $delay )
{
    $recording = $Myth->new_recording($chanid, myth_to_unix_time($starttime));

    if (!$recording || !(exists $recording->{'local_path'}) || 
        !(-f $recording->{'local_path'}) )
    {
        if($recording) {
            print $recording;
        }
        sleep 5;
        cancel() if (-f $cancelfile);
        $delay -= 5;
        if (!$delay) {
            no_recording($cardid, $chanid, $starttime);
            exit(1);
        }
    }
}

# If we get here, we have a recording.
if (-f $recording->{'local_path'})
{
    # And it's local.  Wait 10s if 0 bytes, then check again for 0 byte size.
    my $delay = 1;
    my $filesize = 0;

    while( !$filesize && $delay >= 0 )
    {
        my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
            $atime,$mtime,$ctime,$blksize,$blocks) = 
                stat($recording->{'local_path'});
        $filesize = $size;

        if ($size != 0)
        {
            exit(0);
        }

        sleep 10;
        cancel() if (-f $cancelfile);
        $delay--;
    }

    # #@$$@%ing zero byte file!
    zero_byte($cardid, $chanid, $starttime);
    unlink $runningfile;
    exit(1);
}

unlink $runningfile;
exit 0;

sub touch
{
    my $file = shift;

    open FH, ">", $file;
    print FH "\n";
    close FH;
}

sub cancel
{
    unlink $runningfile;
    unlink $cancelfile;
    exit 0;
}

sub no_recording
{
    my ($cardid, $chanid, $starttime) = @_;

    my $ishdpvr = exists $hdpvrs{$cardid};

    print "No recording for channel $chanid at $starttime\n";
    print "Recording " . ($ishdpvr ? "" : "not ") . "from HD-PVR.\n";

    if ( $ishdpvr )
    {
        my @command = ( "hdpvr-power", $hdpvrs{$cardid}, "cycle" );
        system @command;
    }
}

sub zero_byte
{
    my ($cardid, $chanid, $starttime) = @_;

    my $ishdpvr = exists $hdpvrs{$cardid};

    print "Zero byte recording for channel $chanid at $starttime\n";
    print "Recording " . ($ishdpvr ? "" : "not ") . "from HD-PVR.\n";

    if ( $ishdpvr )
    {
        my @command = ( "hdpvr-power", $hdpvrs{$cardid}, "cycle" );
        system @command;
    }
}

# vim:ts=4:sw=4:ai:et:si:sts=4
