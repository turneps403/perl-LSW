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


sub add {
    my $class = shift;
    my $words = ref $_[0] eq "ARRAY" ? $_[0] : \@_;

    for my $lc_w (uniq map {lc} @$words) {
        $class->instance->dbh->do(
            "INSERT OR IGNORE INTO TrashWords(crc, word) VALUES (?, ?)",
            undef,
            String::CRC32::crc32($lc_w), $lc_w
        );
    }

    return;
}


sub get_crc_multi {
    my ($class, $crcs) = @_;

    my $db_trash = $class->instance->dbh->selectall_arrayref(
        "SELECT * FROM TrashWords WHERE crc IN (".join(',', ('?') x @$crcs).")",
        { Slice => {} },
        @$crcs
    ) or die $class->instance->dbh->errstr;

    my $ret = {};
    for (@$db_trash) {
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
            $ret->{$w} = $res->{$crc} if $res->{$crc};
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
