#!/usr/bin/perl
use strict;
use warnings;

use File::Spec;
use Cwd qw();
use File::HomeDir;

use LWP::UserAgent qw();
use Getopt::Long;
use LSW::Log;
use LSW::Dictionary;

    my $opts = {
        db_folder => '',
        audio_folder => ''
    };
    GetOptions(
        "db_folder=s" => \$opts->{db_folder},
        "audio_folder=s" => \$opts->{audio_folder},
    );

    unless ($opts->{db_folder}) {
        die "No --db_folder specified!";
    }
    $opts->{db_folder} =~ s/^~/File::HomeDir->my_home/e;
    my $db_folder = File::Spec->rel2abs($opts->{db_folder});
    $db_folder = Cwd::realpath($db_folder);
    unless (-d $db_folder) {
        die "No --db_folder specified!";
    }

    unless ($opts->{audio_folder}) {
        die "No --audio_folder specified!";
    }
    $opts->{audio_folder} =~ s/^~/File::HomeDir->my_home/e;
    my $audio_folder = File::Spec->rel2abs($opts->{audio_folder});
    $audio_folder = Cwd::realpath($audio_folder);
    unless (-d $audio_folder) {
        die "No --audio_folder specified!";
    }

    my $lsw = LSW::Dictionary->new(db_folder => $db_folder);
    while (1) {
        my $audio = LSW::Dictionary::DB->sounds->get_unchecked(1);
        unless (@$audio) {
            log_info("No audio file");
            sleep(60);
            next;
        }

        for my $aevent (@$audio) {
            my $localname = File::Spec->catfile( $audio_folder, $aevent->{md5}.'.mp3' );
            my $lwp = LWP::UserAgent->new(
                agent => LSW::Dictionary::Web::UserAgent->get_ua(),
                ssl_opts => {verify_hostname => 0}
            );
            $lwp->protocols_allowed( [ 'http', 'https'] );
            $lwp->timeout(15);
            unless ($lwp->mirror($aevent->{sound_url}, $localname)->{'_rc'} == 200) {
                log_warn("Fail with url", $aevent->{sound_url}, "for", $aevent->{md5});
                LSW::Dictionary::DB->sounds->mark_as_bad($aevent->{md5});
                unlink $localname;
            } else {
                log_info("Success create", $localname, "from url", $aevent->{sound_url});
                LSW::Dictionary::DB->sounds->mark_as_good($aevent->{md5});
            }
            sleep(1);
        }
    }

exit;
__END__

perl -I lib/ -d bin/audio_dumper.pl --db_folder=~/tmp/lsw --audio_folder=~/tmp/lsw/audio
