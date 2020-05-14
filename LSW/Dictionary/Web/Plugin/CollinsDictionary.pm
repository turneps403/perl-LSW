package LSW::Dictionary::Web::Plugin::CollinsDictionary;
use strict;
use warnings;

use URI qw();
use base qw(LSW::Dictionary::Web::BasePlugin);

sub create_url {
    my ($class, $word) = @_;
    my $url = URI->new("https://www.collinsdictionary.com");
    $url->path_segments("dictionary", "english", $word);
    return $url;
}

my $parser = {
    # https://grantm.github.io/perl-libxml-by-example/html.html
    "/word" => [
        sub {
            return shift=~
                # <h2 class="h2_entry"><span class="orth">talk</span></h2>
                /<h2\s+class="h2_entry">\s*<span\s+class="orth">\s*([^<]+)\s*<\/span>\s*<\/h2>/is
            ? $1 : undef;
        }
    ],
    "/sounds[]" => [
        sub {
            return shift=~
                # <a class="hwd_sound sound audio_play_button icon-volume-up ptr" title="Pronunciation for talk" data-src-mp3="https://www.collinsdictionary.com/sounds/hwd_sounds/55710.mp3" data-lang="en_GB"></a>
                /<a[^>]+title="Pronunciation[^>]+data-src-mp3="([^"]+\.mp3)"[^>]+data-lang="en_GB"/is
            ? $1 : undef;
        }
    ],
    "/ipa" => [
        sub {
            # <div class="mini_h2"><span class=" punctuation"> .. </div>
            my ($div) = $_[0] =~ /<div\s+class="mini_h2">\s*<span\s+class="\s*punctuation\s*">(.+?)<\/div>/s;
            return unless $div;
            # s/<span class="hi rend-u">([^<]*)<\/span>/\t$1\t/ <- emphasis
            $div =~ s/<span class="hi rend-u">([^<]*)<\/span>/\t$1\t/g;
            $div =~ s/<[^>]+>//g;
            $div =~ s/^\s*\(\s*//;
            $div =~ s/\s*\)\s*$//;
            return $div;
        }
    ]
};


sub parse {
    my ($class, $html) = @_;
    my $ret = {};
    for my $dpath (keys %$parser) {
        my $value = undef;
        for my $vsub (@{$parser->{$dpath}}) {
            my $vret = $vsub->($html);
            next unless $vret;
            if ($dpath =~ /\[\]$/) {
                $value ||= [];
                push @$value, $vret;
            } else {
                $value = $vret;
                last;
            }
        }
        if ($value) {
            $class->_place_value($ret, $dpath, $value);
        }
    }
    return $ret;
}

sub _place_value {
    my ($class, $target, $dpath, $value) = @_;
    # surface version of data path
    my @dpath = split('/', $dpath);
    shift @dpath unless $dpath[0];
    for my $i (0 .. $#dpath) {
        if ($i == $#dpath) {
            $dpath[$i] =~ s/\[\]$//;
            $target->{ $dpath[$i] } = $value;
        } else {
            $target = $target->{ $dpath[$i] } ||= {};
        }
    }
    return;
}

sub weight { 100 }

1;
__END__
