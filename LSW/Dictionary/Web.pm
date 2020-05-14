package LSW::Dictionary::Web;
use strict;
use warnings;

use String::CRC32 qw();
use Module::Util qw();
use Module::Load qw();

use AnyEvent;
use AnyEvent::HTTP;
# use XML::LibXML;

use LSW::Dictionary::Web::UserAgent qw();

$LSW::Dictionary::WebSeeker::plugins = [];
for ( Module::Util::find_in_namespace(__PACKAGE__ . "::Plugin") ) {
    Module::Load::load($_) unless Module::Util::module_is_loaded($_);
    if (UNIVERSAL::isa($_, "LSW::Dictionary::Web::BasePlugin")) {
        push @$LSW::Dictionary::WebSeeker::plugins, $_;
    }
}

sub resolve {
    my $class = shift;
    my $params = {};
    if (ref $_[-1] eq 'HASH') {
        $params = pop(@_);
    }
    my $words = ref $_[0] eq "ARRAY" ? $_[0] : \@_;
    return {} unless @$words;

    my $lcmap = {};
    for my $w (@$words) {
        my $lcw = lc $w;
        if (exists $lcmap->{ $lcw }) {
            push @{ $lcmap->{ $lcw } }, $w;
        } else {
            $lcmap->{ $lcw } = [$w];
        }
    }

    my @tmp = keys %$lcmap;
    while (my @chunk = splice(@tmp, 0, $params->{chunk_size} || 3)) {
        my $req = [];
        for my $pl (@$LSW::Dictionary::WebSeeker::plugins) {
            for my $w (@chunk) {
                push @$req, { url => $pl->create_url($w), word => $w, pl => $pl, body => '', res => undef };
            }
        }

        $class->fetch_urls($req);
        $class->parse_urls($req);
        1;
        # for my $r (@$req) {
        #     next unless $r->{body};
        #     #my $dom = XML::LibXML->load_html(
        #     # my $dom = XML::LibXML->parse_html_string(
        #     #     string => delete $r->{body},
        #     #     {
        #     #         recover => 1,
        #     #         expand_entities => 0,
        #     #         load_ext_dtd => 0,
        #     #         validation => 0,
        #     #         no_network => 1,
        #     #         # suppress_errors => 1,
        #     #     }
        #     # );
        #     $r->{res} = $r->{pl}->parse($r->{body});
        #     1;
        # }

      #   DB<<4>> x $req->[0]->{res}
      # 0  HASH(0x7fea2fa59af0)
      #    'ipa' => "t\cIɔː\cIk"
      #    'sounds' => ARRAY(0x7fea30505070)
      #       0  'https://www.collinsdictionary.com/sounds/hwd_sounds/55710.mp3'
      #    'word' => 'talk'
      #   DB<<5>> x $req->[1]->{res}
      # 0  HASH(0x7fea2f12d430)
      #    'ipa' => "t\cIɒ\cIm"
      #    'sounds' => ARRAY(0x7fea2fc80e00)
      #       0  'https://www.collinsdictionary.com/sounds/hwd_sounds/57295.mp3'
      #    'word' => 'tom'


    }
    1;
}

sub parse_urls {
    my ($class, $req) = @_;
    for my $r (@$req) {
        next unless $r->{body};
        $r->{res} = $r->{pl}->parse($r->{body});
    }
    return;
}

sub fetch_urls {
    my ($class, $req) = @_;

    AnyEvent->now_update;
    my $cv = AnyEvent->condvar;
    $cv->begin;
    for my $r (@$req) {
        my $ua = LSW::Dictionary::Web::UserAgent->get_ua();
        $cv->begin;
        http_get $r->{url},
        timeout => 10, headers => {"User-Agent" => $ua},
        sub {
            my ($body, $hdr) = @_;
            if (int $hdr->{Status} == 200) {
                $r->{body} = $body;
            } else {
                warn("knock to ".$r->{url}." (real: ".$hdr->{URL}.") fail: status ".$hdr->{Status}." UA: $ua");
            }
            $cv->end;
        };
    }
    $cv->end;
    $cv->recv;

    return;
}

1;
__END__
