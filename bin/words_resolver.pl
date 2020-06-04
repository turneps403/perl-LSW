#!/usr/bin/perl
use strict;
use warnings;

use File::Spec;
use Cwd qw();
use File::HomeDir;

use Getopt::Long;
use LSW::Dictionary;

=pod

    Simple example for translate small files

=cut

    my $opts = {
        file => '',
        db_folder => ''
    };
    GetOptions(
        "file=s" => \$opts->{file},
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

    unless ($opts->{file}) {
        die "No --file specified!";
    }
    $opts->{file} =~ s/^~/File::HomeDir->my_home/e;
    my $file = File::Spec->rel2abs($opts->{file});
    $file = Cwd::realpath($file);
    unless (-f $file and -s _) {
        die "No --file specified!";
    }

    open(IN, "<", $file) or die $!;
        my $content = join('', <IN>);
    close(IN);

    my @words = $content =~ /(\w{1,240})/g;

    my $lsw = LSW::Dictionary->new(db_folder => $db_folder, queue_enable => 1);
    my $ipa_dict = $lsw->db_lookup(@words);

    $content =~ s/(\w{1,240})/$ipa_dict->{$1} ? "$1 (".$ipa_dict->{$1}->{ipa}.")" : "-$1-"/seg;

    print $content . "\n";

exit;
__END__

perl -I lib/ -d bin/words_resolver.pl --db_folder=~/tmp/lsw --file=~/tmp/lsw/test.txt
