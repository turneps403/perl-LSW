package LSW::Dictionary::DB::Trash;
use strict;
use warnings;

use String::CRC32 qw();
use List::MoreUtils qw(uniq);

use base qw(LSW::Dictionary::DB::Base);

sub check_or_create_tables {
    my $self = shift;

    my @q = (
        "
            CREATE TABLE IF NOT EXISTS TrashWords (
                crc INTEGER NOT NULL PRIMARY KEY,
                word VARCHAR(255) NOT NULL
            )
        "
    );

    for (@q) {
        $self->dbh->do($_) or die "could not create tables...$!\n";
    }

    return;
}

sub lookup {
    my $class = shift;
    my $words = ref $_[0] eq "ARRAY" ? $_[0] : \@_;
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
        my $tmp_res = $class->instance->dbh->selectall_arrayref(
            "SELECT * FROM TrashWords WHERE crc IN (".join(",", ('?')x@chunk).")",
            { Slice => {} },
            @chunk
        ) or die $class->instance->dbh->errstr;
        for (@$tmp_res) {
            $res->{ $_->{crc} } = 1;
        }
    }

    my $ret = {};
    for my $crc (keys %$lcmap) {
        for my $source_word (@{ $lcmap->{$crc} }) {
            $ret->{$source_word} = $res->{$crc} ? 1 : 0;
        }
    }

    return $ret;
}

sub add {
    my $class = shift;
    my $words = ref $_[0] eq "ARRAY" ? $_[0] : \@_;

    for my $w (uniq map {lc} @$words) {
        $class->instance->dbh->do(
            "INSERT INTO TrashWords(crc, word) VALUES (?, ?)",
            String::CRC32::crc32($w), $w
        );
    }

    return;
}

1;
__END__
