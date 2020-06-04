package LSW::Dictionary::Web::Plugin::CollinsDictionary;
use strict;
use warnings;

use URI qw();
use base qw(LSW::Dictionary::Web::BasePlugin);


sub weight { 100 }


sub create_url {
    my ($class, $word) = @_;
    my $url = URI->new("https://www.collinsdictionary.com");
    $url->path_segments("dictionary", "english", $word);
    return $url;
}


sub _escape {
    my $token = shift;
    $token =~ s/</&lt;/g;
    $token =~ s/>/&gt;/g;
    $token ~= /^\s+//;
    $token ~= /\s+$//;
    return lc $token;
}


# any way i still have https://grantm.github.io/perl-libxml-by-example/html.html
# but regex looks also flexible and fast to future changes
sub search_main_word {
    my ($class, $html) = @_;
    my $ret = {
        word => '',
        ipa => '',
        sound => []
    };

    ## WORD
    # <h2 class="h2_entry"><span class="orth">talk</span></h2>
    my ($word) = $html =~ /<h2\s+class="h2_entry">\s*<span\s+class="orth">\s*([^<]+)\s*<\/span>\s*<\/h2>/is;
    return $ret unless $word;

    ## SOUND
    # <a class="hwd_sound sound audio_play_button icon-volume-up ptr" title="Pronunciation for talk" data-src-mp3="https://www.collinsdictionary.com/sounds/hwd_sounds/55710.mp3" data-lang="en_GB"></a>
    my ($sound) = $html =~ /<a[^>]+title="Pronunciation[^>]+data-src-mp3="([^"]+\.mp3)"[^>]+data-lang="en_GB"/is;
    if ($sound) {
        push @{ $ret->{sound} ||= [] }, URI->new($sound)->as_string;
    }

    ## IPA
    # <div class="mini_h2"><span class=" punctuation"> .. </div>
    my ($div) = $html =~ /<div\s+class="mini_h2">\s*<span\s+class="\s*punctuation\s*">(.+?)<\/div>/s;
    if ($div) {
        # s/<span class="hi rend-u">([^<]*)<\/span>/\t$1\t/ <- emphasis
        $div =~ s/<span class="hi rend-u">([^<]*)<\/span>/\t$1\t/g;
        $div =~ s/<[^>]+>//g;
        $div =~ s/^\s*\(\s*//;
        $div =~ s/\s*\)\s*$//;
        $ret->{ipa} = _escape($div);
    }

    return $ret;
}


sub search_derivatives_words {
    my ($class, $html) = @_;

    # OTHER DERIVATIVES OF WORD
    my $ret = [];
    #<span class="orth"> talks</span><span class="ptr hwd_sound type-hwd_sound">
    #<a class="hwd_sound sound audio_play_button icon-volume-up ptr" title="Pronunciation for talks" data-src-mp3="https://www.collinsdictionary.com/sounds/hwd_sounds/55737.mp3" data-lang="en_GB"></a>
    my @others = $html =~ /<span\s+class="orth">([^<]+)</span>\s*<span\s+class="ptr\s+hwd_sound\s+type-hwd_sound">\s*<a\s+class="hwd_sound\s+.+?data-src-mp3="([^"]+)"/;
    while (my @chunk = splice(@others, 0, 2)) {
        my ($fk_word, $fk_sound) = @chunk;
        push @$ret, {
            word => _escape($fk_word),
            ipa => '',
            sound => $fk_sound ? [URI->new($fk_sound)->as_string] : [],
        }
    }

    return $ret;
}


1;
__END__
