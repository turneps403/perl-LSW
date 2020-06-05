package LSW::Dictionary::Web;
use strict;
use warnings;

use List::MoreUtils qw(uniq);
use Module::Util qw();
use Module::Load qw();

use AnyEvent;
use AnyEvent::HTTP;

use LSW::Log;
use LSW::Dictionary::Web::UserAgent qw();

$LSW::Dictionary::WebSeeker::plugins = [];
for ( Module::Util::find_in_namespace(__PACKAGE__ . "::Plugin") ) {
    Module::Load::load($_) unless Module::Util::module_is_loaded($_);
    if (UNIVERSAL::isa($_, "LSW::Dictionary::Web::BasePlugin")) {
        log_info("Found a plugin:", $_);
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
        log_info("Try to resolve words:", \@chunk);
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
            my @bad_urls = grep { $_->{status} == 500 } @$reqs;
            unless (@bad_urls) {
                last;
            } else {
                log_warn("Urls got 500:", [map { $_->{url} } @bad_urls]);
            }
            sleep(1.1 + sprintf '%0.2f', rand(1)); # TODO: reinvoke over queue
        }

        for my $req (@$reqs) {
            unless ($req->{body}) {
                # TODO: logging unaccepatble word
                log_warn("Fail req:", $req);
                next;
            }
            my $main_word = $req->{pl}->search_main_word($req->{body});
            if ($main_word and $main_word->{word}) {
                LSW::Dictionary::DB->add_word($main_word);
                if ($main_word->{word} ne $req->{word}) {
                    log_info("Word", $req->{word}, "was resolved as", $main_word->{word});
                    LSW::Dictionary::DB->add_symbolic_link($req, $main_word);
                }
                my $fks = $req->{pl}->search_derivatives_words($req->{body});
                if ($fks and @$fks) {
                    for (@$fks) {
                        log_info("Found derivative", [$_->{word}], "for", [$main_word->{word}]);
                        unless ( LSW::Dictionary::DB->words->get($_->{word}) ) {
                            # words that already exisis, at least once were in a queue
                            # so, try to extend them but not add to a queue
                            # as absolutly novice
                            LSW::Dictionary::DB->add_word($_);
                            LSW::Dictionary::DB->queue->add($_->{word});
                        }
                        LSW::Dictionary::DB->add_word($_);
                        LSW::Dictionary::DB->add_fk($main_word, $_);
                    }
                } else {
                    log_info("Derivatives wasnt found at url", $req->{url});
                }
            } else {
                # TODO: to trash
                log_warn("Fail parse word", [$req->{word}], "by url", [$req->{url}]);
                unless ( LSW::Dictionary::DB->words->get($req->{word}) ) {
                    # word from words db cant be trashed
                    LSW::Dictionary::DB->trash->add($req->{word});
                }
            }
            LSW::Dictionary::DB->queue->del($req->{word});
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
                log_dbg("Url", $r->{url}, "fetched successfully");
                $r->{body} = $body;
                $r->{status} = 200;
            } else {
                $r->{status} = int $hdr->{Status};
                log_warn("knock to", $r->{url}, "(real:", $hdr->{URL}, ") fail: status", $hdr->{Status}, "UA: $ua");
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
