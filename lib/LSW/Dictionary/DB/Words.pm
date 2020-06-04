package LSW::Dictionary::DB::Words;
use strict;
use warnings;

use base qw(LSW::Dictionary::DB::Base);
use String::CRC32 qw();


sub check_or_create_tables {
    my $self = shift;

    my @q = (
        "
            -- just words with ipa, ipa is optional
            CREATE TABLE IF NOT EXISTS Words (
                crc INTEGER NOT NULL PRIMARY KEY,
            	word VARCHAR(255) NOT NULL,
                ipa VARCHAR(255)
            )
        "
    );

    for (@q) {
        $self->dbh->do($_) or die "could not create tables...$!\n";
    }

    return;
}


sub add {
    my ($class, $word) = @_;
    return unless $word->{word};
    $word->{crc} ||= String::CRC32::crc32(lc $word->{word});

    my $db_word = $class->get($word->{word});
    unless ($db_word) {
        $class->instance->dbh->do(
            "INSERT OR IGNORE INTO Words(crc, word, ipa) VALUES (?, ?, ?)",
            undef,
            $word->{crc}, $word->{word}, $word->{ipa} || ''
        );
    } elsif ($word->{ipa} and not $db_word->{ipa}) {
        $class->instance->dbh->do(
            "UPDATE Words SET ipa = ? WHERE crc = ?",
            undef,
            $word->{ipa}, $word->{crc}
        );
    }

    return;
}

sub get_crc_multi {
    my ($class, $crcs) = @_;

    my $db_words = $class->instance->dbh->selectall_arrayref(
        "SELECT * FROM Words WHERE crc IN (".join(',', ('?') x @$crcs).")",
        { Slice => {} },
        @$crcs
    ) or die $class->instance->dbh->errstr;

    my $ret = {};
    for (@$db_words) {
        $ret->{ $_->{crc} } = $_;
    }

    return $ret;
}

sub get_multi {
    my ($class, $words_str) = @_;

    my $crc_map = {};
    for (@$words_str) {
        push @{ $crc_map->{ String::CRC32::crc32(lc $_) } ||= [] }, $_;
    }
    my $res = $class->get_crc_multi([keys %$crc_map]);

    my $ret = {};
    for my $crc (keys %$crc_map) {
        for my $w ( @{$crc_map->{$crc}} ) {
            $ret->{$w} = $res->{$crc};
        }
    }

    return $ret;
}

sub get {
    my ($class, $word_str) = @_;
    return $class->get_multi([$word_str])->{$word_str};
}


1;
__END__
