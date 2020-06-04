#!/usr/bin/perl
use strict;
use warnings;

use File::Spec;
use Cwd qw();
use File::HomeDir;

use Getopt::Long;
use LSW::Dictionary;

=pod

    A queue worker who receives events from a database queue
    and does a word search on the net according to plugins.

=cut

    my $opts = {
        limit => 1,
        db_folder => ''
    };
    GetOptions(
        "limit=s" => \$opts->{limit},
        "db_folder=s" => \$opts->{db_folder},
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

    my $lsw = LSW::Dictionary->new(db_folder => $db_folder);
    while (1) {
        my $cnt = $lsw->web_lookup($opts->{limit});
        if ($cnt) {
            sleep(1);
        } else {
            sleep(5);
        }
    }

exit;
__END__

perl -I lib/ -d bin/queue_slot.pl --db_folder=~/tmp/lsw
