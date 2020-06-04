package LSW::Dictionary::DB::Sounds;
use strict;
use warnings;

use String::CRC32 qw();
use Digest::MD5 qw();

use base qw(LSW::Dictionary::DB::Base);

my $STATUS_UNCHECKED = 0;
my $STATUS_GOOD = 1;
my $STATUS_BAD = 2;

sub check_or_create_tables {
    my $self = shift;

    my @q = (
        "
            -- where sounds can be found
            -- statuses: 0 not checked, 1 good, 2 fail
            CREATE TABLE IF NOT EXISTS Sounds (
                md5 varchar(32) NOT NULL PRIMARY KEY,
                crc INTEGER NOT NULL,
                sound_url Text,
                status INTEGER NOT NULL DEFAULT 0
            )
        ",
        "
            CREATE INDEX IF NOT EXISTS idx_sounds_status ON Sounds (status, crc)
        "
    );

    for (@q) {
        $self->dbh->do($_) or die "could not create tables...$!\n";
    }

    return;
}


sub get_crc {
    my ($class, $crc) = @_;
    return $class->get_crc_multi([$crc])->{$crc} || [];
}


sub get_crc_multi {
    my ($class, $crcs) = @_;

    my $db_links = $class->instance->dbh->selectall_arrayref(
        "SELECT * FROM Sounds WHERE status = ? AND crc IN (".join(',', ('?') x @$crcs).")",
        { Slice => {} },
        $STATUS_GOOD,
        @$crcs
    ) or die $class->instance->dbh->errstr;

    my $ret = {};
    for (@$db_links) {
        push @{ $ret->{ $_->{crc} } ||= [] }, $_;
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
            $ret->{$w} = $res->{$crc} || [];
        }
    }

    return $ret;
}


sub get {
    my ($class, $word_str) = @_;
    return $class->get_multi([$word_str])->{$word_str};
}


sub add {
    my ($class, $word) = @_;
    return unless $word->{word} and $word->{sound} and @{$word->{sound}};
    my $crc = String::CRC32::crc32(lc $word->{word});

    for (@{ $word->{sound} }) {
        $class->instance->dbh->do(
            "INSERT OR IGNORE INTO Sounds(md5, crc, sound_url, status) VALUES (?, ?, ?, ?)",
            undef,
            Digest::MD5::md5_hex($crc . $_), $crc, $_, $STATUS_UNCHECKED
        );
    }

    return;
}


sub mark_as_good {
    my ($class, $md5) = @_;
    return $class->_mark_as($md5, $STATUS_GOOD);
}


sub mark_as_bad {
    my ($class, $md5) = @_;
    return $class->_mark_as($md5, $STATUS_BAD);
}


sub _mark_as {
    my ($class, $md5, $status) = @_;
    $class->instance->dbh->do(
        "UPDATE Sounds SET status = ? WHERE md5 = ?",
        undef,
        $status, $md5
    );
    return;
}

1;
__END__
