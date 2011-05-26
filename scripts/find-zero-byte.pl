#! /usr/bin/perl

use warnings;
use strict;

use lib '/opt/mythtv/new-logging/share/perl/5.10.1';

use MythTV;

# Fill in this hash with cardid => serial number for each HDPVR, power device
# pair.  If a zero-byte file is detected from any device in here, its power 
# will be turned off for 15s, then back on
my %hdpvrs = ( 32 => "GHUD9O5F" );

my $Myth = new MythTV();

# $0 cardid chanid starttime
my ($cardid, $chanid, $starttime) = @ARGV;

die "You must provide cardid, chanid, starttime!\n"
   if (!$cardid || !$chanid || !$starttime);

my $recording = undef;
my $delay = 30;

while ((!$recording || !(exists $recording->{'local_path'}) || 
        !(-f $recording->{'local_path'})) && $delay )
{
    $recording = $Myth->new_recording($chanid, myth_to_unix_time($starttime));

    if (!$recording || !(exists $recording->{'local_path'}) || 
        !(-f $recording->{'local_path'}) )
    {
        sleep 5;
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
        $delay--;
    }

    # #@$$@%ing zero byte file!
    zero_byte($cardid, $chanid, $starttime);
    exit(1);
}

exit 0;


sub no_recording
{
    my ($cardid, $chanid, $starttime) = @_;

    my $ishdpvr = exists $hdpvrs{$cardid};

    print "No recording for channel $chanid at $starttime\n";
    print "Recording " . ($ishdpvr ? "" : "not ") . "from HD-PVR.\n";
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
