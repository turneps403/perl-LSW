#!/usr/bin/perl
use strict;
use warnins;

use Getopt::Long;
use LSW::Dictionary;

    GetOptions(
        "file=s" => \my $file,
        "words_db_path=s" => \my $words_db_path,
    );

    unless (-f $file) {
        die "No --file specified!";
    }

    open(IN, "<", $file) or die $!;
        my $content = join('', <IN>);
    close(IN);

    my @words = $content =~ /(\w+)/g;

    my $lsw = LSW::Dictionary->new(words_db_path => $words_db_path);
    my $ipa_dict = $lsw->words2ipa(@words);

    $content =~ s/(\w+)/$lsw->get($1) || "-$1-"/seg;

    print $content . "\n";

exit;
__END__
