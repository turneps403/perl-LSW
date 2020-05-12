package LSW::Dictionary::DB::Words;
use strict;
use warnings;

use base qw(LSW::Dictionary::DB::Base);
use String::CRC32 qw();

sub check_or_create_tables {
    my $self = shift;

    $dbh->do("
        -- just words with ipa, sometimes ipa doesn't exists
        CREATE TABLE IF NOT EXISTS Words (
            crc INTEGER NOT NULL PRIMARY KEY,
        	word VARCHAR(255) NOT NULL,
            ipa VARCHAR(255)
        );

        -- to describe word lekation to others words
        CREATE TABLE IF NOT EXISTS WordLinks (
            crc INTEGER NOT NULL,
            fk INTEGER NOT NULL
        );
        CREATE UNIQUE INDEX IF NOT EXISTS idx_sounds_crc ON WordLinks (crc, fk);
    ") or die "could not create tables...$!\n";

    return;
}

sub lookup {
    my $self = shift;
    my $words = ref $_[0] == "ARRAY" ? $_[0] : \@_;
    return {} unless @$words;

    my $lcmap = {};
    for my $w (@$words) {
        my $crc = String::CRC32::crc32(lc $w);
        if (exists $lcmap->{ $crc }) {
            push @{ $lcmap->{ $crc } }, $w;
        } else {
            $lcmap->{ $crc } = [$w];
        }
    }

    my $res = {};
    my @crc_uniq = keys %$lcmap;
    while (my @chunk = splice(@crc_uniq, 0, 100)) {
        my $tmp_res = $self->dbh->selectall_arrayref(
            "SELECT * FROM Words WHERE crc IN (".join(",", ('?')x@chunk).")",
            "crc",
            @chunk
        ) or die $self->dbh->errstr;

        $_->{fk}  = [] for values %$tmp_res;

        if (%$tmp_res) {
            my $db_links = $self->dbh->selectall_arrayref(
                "SELECT * FROM WordLinks WHERE crc IN (".join(",", ('?')x%$tmp_res).")",
                { Slice => {} },
                keys %$tmp_res
            ) or die $self->dbh->errstr;
            for (@$db_links) {
                push @{ $tmp_res->{ $_->{crc} }->{fk} }, $_->{fk}
            }
        }
        @$res{ keys %$tmp_res } = values %$tmp_res;
    }

    my $ret = {};
    for my $crc (keys %$lcmap) {
        for my $source_word (@{ $lcmap->{$crc} }) {
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
