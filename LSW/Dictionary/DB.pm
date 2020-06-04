package LSW::Dictionary::DB;
use strict;
use warnings;

use Module::Util qw();
use Module::Load qw();

for ( Module::Util::find_in_namespace(__PACKAGE__) ) {
    next if /::Base$/;
    Module::Load::load($_) unless Module::Util::module_is_loaded($_);
}

sub words()  { __PACKAGE__ . "::Words" }
sub fk()     { __PACKAGE__ . "::FK" }
sub sounds() { __PACKAGE__ . "::Sounds" }
sub trash()  { __PACKAGE__ . "::Trash" }
sub queue()  { __PACKAGE__ . "::Queue" }

sub add_word {
    my ($class, $word) = @_;
    $class->words->add($word);
    $class->sounds->add($word);
    return;
}

sub add_fk {
    my ($class, $word, $derivative) = @_;
    $class->fk->add($word, $derivative);
    return;
}

sub add_symbolic_link {
    my ($class, $word, $derivative) = @_;
    $class->fk->add($word, $derivative, 'symbolic link to other word');
    return;
}


sub lookup {
    my ($class, $words, $opt) = @_;
    $opt ||= {};
    return {} unless @$words;

    my $crcmap = {};
    for my $w (@$words) {
        my $crc = String::CRC32::crc32(lc $w);
        push @{ $crcmap->{ $crc } ||= [] }, $w;
    }

    my $res = {};
    my @crc_uniq = keys %$crcmap;
    while (my @chunk = splice(@crc_uniq, 0, 100)) {
        my $wres = $class->words->get_crc_multi(\@chunk);

        if (keys %$wres) {
            my $sres = $class->sounds->get_crc_multi([keys %$wres]);
            my $fks = $class->fk->get_crc_multi([keys %$wres]);
            for my $crc (keys %$wres) {
                $res->{ $crc } = {
                    word => $wres->{$crc}->{word},
                    ipa => $wres->{$crc}->{ipa},
                    sound => $sres->{$crc} ? [ map { $_->{md5} } @$sres->{$crc} ] : [],
                    fk => $fks->{$crc} || [],
                };
            }
        }

        my @not_found = grep { not $wres->{$_} } @chunk;
        if (@not_found) {
            my $with_fk_only = $class->fk->get_crc_multi(\@not_found);
            for my $crc (keys %$with_fk_only) {
                $res->{ $crc } = {
                    word => '',
                    ipa => '',
                    sound => [],
                    fk => $with_fk_only->{$crc} || [],
                };
            }

            if ($opt->{queue_enable}) {
                @not_found = grep { not $with_fk_only->{$_} } @not_found;
                if (@not_found) {
                    my $trash = $class->trash->get_crc_multi(\@not_found);
                    my @new_words_crc = grep { not $trash->{$_} } @not_found;
                    if (@new_words_crc) {
                        # to queue
                        $class->queue->add([ map { lc $crcmap->{$_}->[0] } @new_words_crc ]);
                    }
                }
            }
        }
    }

    my $ret = {};
    for my $crc (keys %$crcmap) {
        for my $source_word (@{ $crcmap->{$crc} }) {
            if ($res->{$crc}) {
                $ret->{$source_word} = $res->{$crc};
            } else {
                # empty hash for not founded word
                $ret->{$source_word} = {};
            }
        }
    }

    return $ret;
}


1;
__END__
