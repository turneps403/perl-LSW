package LSW::Dictionary::Web;
use strict;
use warnings;

use List::MoreUtils qw(uniq);
use String::CRC32 qw();
use Module::Util qw();
use Module::Load qw();

use AnyEvent;
use AnyEvent::HTTP;

use LSW::Dictionary::Web::UserAgent qw();

$LSW::Dictionary::WebSeeker::plugins = [];
for ( Module::Util::find_in_namespace(__PACKAGE__ . "::Plugin") ) {
    Module::Load::load($_) unless Module::Util::module_is_loaded($_);
    if (UNIVERSAL::isa($_, "LSW::Dictionary::Web::BasePlugin")) {
        push @$LSW::Dictionary::WebSeeker::plugins, $_;
    }
}
@$LSW::Dictionary::WebSeeker::plugins = sort { $b->weight <=> $a->weight } @$LSW::Dictionary::WebSeeker::plugins;

sub resolve {
    my $class = shift;
    my $params = {};
    if (ref $_[-1] eq 'HASH') {
        $params = pop(@_);
    }
    my $words = ref $_[0] eq "ARRAY" ? $_[0] : \@_;
    return {} unless @$words;

    my @uniq_lc_words = uniq map {lc} @$words;
    while (my @chunk = splice(@uniq_lc_words, 0, $params->{chunk_size} || 3)) {
        my $reqs = [];
        for my $pl (@$LSW::Dictionary::WebSeeker::plugins) {
            for my $w (@chunk) {
                push @$reqs, {
                    url => $pl->create_url($w),
                    word => $w,
                    pl => $pl,
                    status => 0,
                    body => '',
                    res => undef
                };
            }
        }

        my $retry = abs int ($params->{retry} || 3);
        while (
            scalar( grep { $_->{status} == 0 } @$reqs )
            or $retry--
        ) {
            $class->fetch_urls($reqs);
            unless (grep { $_->{status} == 500 } @$reqs) {
                last;
            }
            sleep(1.1 + sprintf '%0.2f', rand(1)); # TODO: reinvoke over queue
        }

        for my $req (@$reqs) {
            unless ($req->{body}) {
                # TODO: logging unaccepatble word
                next;
            }
            my $main_word = $req->{pl}->search_main_word($req->{body});
            if ($main_word and $main_word->{word}) {
                LSW::Dictionary::DB->add_word($main_word);
                if ($main_word->{word} ne $req->{word}) {
                    LSW::Dictionary::DB->add_symbolic_link($req, $main_word);
                }
                my $fks = $req->{pl}->search_derivatives_words($req->{body});
                if ($fks and @$fks) {
                    for (@$fks) {
                        LSW::Dictionary::DB->add_word($_);
                        LSW::Dictionary::DB->add_fk($main_word, $_);
                        LSW::Dictionary::DB->queue->add($_->{word});
                    }
                }
            } else {
                # TODO: to trash
                LSW::Dictionary::DB->trash->add($req->{word});
            }
        }
    }

    return;
}


sub fetch_urls {
    my ($class, $req) = @_;

    AnyEvent->now_update;
    my $cv = AnyEvent->condvar;
    $cv->begin;
    for my $r (@$req) {
        next if $r->{body};
        my $ua = LSW::Dictionary::Web::UserAgent->get_ua();
        $cv->begin;
        http_get $r->{url},
        timeout => 10, headers => {"User-Agent" => $ua},
        sub {
            my ($body, $hdr) = @_;
            if (int $hdr->{Status} == 200) {
                $r->{body} = $body;
                $r->{status} = 200;
            } else {
                $r->{status} = int $hdr->{Status};
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
