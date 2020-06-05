package LSW::Dictionary::DB::FK;
use strict;
use warnings;

use base qw(LSW::Dictionary::DB::Base);
use String::CRC32 qw();

use LSW::Log;

sub check_or_create_tables {
    my $self = shift;

    my @q = (
        "
            -- to describe word relations with others words
            CREATE TABLE IF NOT EXISTS WordLinks (
                crc INTEGER NOT NULL,
                fk INTEGER NOT NULL
            )
        ",
        "
            CREATE UNIQUE INDEX IF NOT EXISTS idx_crc_fk ON WordLinks (crc, fk)
        "
    );

    for (@q) {
        $self->dbh->do($_) or die "could not create tables...$!\n";
    }

    return;
}


sub add {
    my ($class, $word, $derivative, $one_way_graph) = @_;
    # use $one_way_graph as true when plagin responded with 200 but another word
    return unless $word->{word} and $derivative->{word};
    $class->instance->dbh->do(
        "INSERT OR IGNORE INTO WordLinks(crc, fk) VALUES (?, ?)",
        undef,
        String::CRC32::crc32(lc $word->{word}),
        String::CRC32::crc32(lc $derivative->{word})
    );
    log_info("added link", [lc $word->{word}, lc $derivative->{word}]);
    unless ($one_way_graph) {
        $class->instance->dbh->do(
            "INSERT OR IGNORE INTO WordLinks(crc, fk) VALUES (?, ?)",
            undef,
            String::CRC32::crc32(lc $derivative->{word}),
            String::CRC32::crc32(lc $word->{word})
        );
        log_info("added link", [lc $derivative->{word}, lc $word->{word}]);
    }

    return;
}

sub get_crc_multi {
    my ($class, $crcs) = @_;

    my $db_links = $class->instance->dbh->selectall_arrayref(
        "SELECT * FROM WordLinks WHERE crc IN (".join(',', ('?') x @$crcs).")",
        { Slice => {} },
        @$crcs
    ) or die $class->instance->dbh->errstr;

    my $ret = {};
    for (@$db_links) {
        push @{ $ret->{ $_->{crc} } ||= [] }, $_->{fk};
    }

    return $ret;
}


sub get_multi {
    my ($class, $words_str) = @_;
    return $class->get_crc_multi([ map { String::CRC32::crc32(lc $_) } @$words_str ]);
}


sub get {
    my ($class, $word_str) = @_;
    my $crc = String::CRC32::crc32(lc $word_str);
    return $class->get_multi([$word_str])->{$crc} || [];
}


1;
__END__
