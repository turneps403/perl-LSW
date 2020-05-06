package LSW::Dictionary::WebSeeker;
use strict;
use warnings;

use String::CRC32 qw();
use Module::Util qw();
use Module::Load qw();

use AnyEvent;
use AnyEvent::HTTP;
use XML::LibXML;

use LSW::Dictionary::WebSeeker::UserAgent qw();

# can be called outside to change priority
$LSW::Dictionary::WebSeeker::plugins_weight = {};
for ( Module::Util::find_in_namespace(__PACKAGE__) ) {
    next unless /Plugin$/;
    next if /::BasePlugin$/;
    Module::Load::load($_) unless Module::Util::module_is_loaded($_);
    if (UNIVERSAL::isa($_, __PACKAGE__ . "::BasePlugin")) {
        $LSW::Dictionary::WebSeeker::plugins_weight->{$_} = $_->weight;
    }
}

sub get_words {
    my $self = shift;
    my $words = ref $_[0] == "ARRAY" ? $_[0] : \@_;
    return {} unless @$words;

    my @words = grep {
        /[0..9]/
        || /^[bcdfghjklmnpqrstvxzwy]+$/i # consonants only
        || (/^[aeiou]+$/i && $_!~/^(a|ie)$/i) # wouvels only
    } @$words;
    return {} unless @$words;

    my $ret = {};
    for my $plugin (sort {
        $LSW::Dictionary::WebSeeker::plugins_weight->{$b}
        <=>
        $LSW::Dictionary::WebSeeker::plugins_weight->{$a}
    } keys %$LSW::Dictionary::WebSeeker::plugins_weight) {
        # TODO: now we count word as completed even if it doesnt have sound
        my @words = grep { not exists $ret->{$_} } @$words;
        last unless @words;

        # words can be not uniq
        my $crc_map = {};
        for (@words) {
            my $crc = String::CRC32::crc32(lc $_);
            if (exists $crc_map->{ $crc }) {
                push @{ $crc_map->{ $crc } }, $_;
            } else {
                $crc_map->{ $crc } = [$_];
            }
        }

        my $urls_map = {};
        @$urls_map{ $plugin->create_urls( map { $_->[0] } values %$crc_map ) } = map {+{crc => $_}} keys %$crc_map;

        my @all_urls = keys %$urls_map;
        while (my @url_chunk = splice(@all_urls, 0, $plugin->req_per_loop)) {
            my $urls_body = {};
            AnyEvent->now_update;
            my $cv = AnyEvent->condvar;
            $cv->begin;
            for my $u (@url_chunk) {
                $cv->begin;
                http_get $u,
                timeout => 5, headers => {"User-Agent": LSW::Dictionary::UserAgent->get_ua()},
                sub {
                    my ($body, $hdr) = @_;
                    if (int $hdr->{Status} == 200) {
                        warn("success knock to".$hdr->{URL});
                        $urls_body->{$u} = $body;
                    } else {
                        warn("knock to $u (real: ".$hdr->{URL}.") fail: status ".$hdr->{Status});
                    }
                    $cv->end;
                };
            }
            $cv->end;
            $cv->recv;


            for my $u (keys %$urls_body) {
                #parse_html_string
                #my $dom = XML::LibXML->load_html(
                my $dom = XML::LibXML->parse_html_string(
                    string => $urls_body->{$u},
                    {
                        recover => 1,
                        expand_entities => 0,
                        load_ext_dtd => 0,
                        validation => 0,
                        no_network => 1,
                        # suppress_errors => 1,
                    }
                );

            }


        }


    }



}

1;
__END__
