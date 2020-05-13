package LSW::Dictionary::DB::Queue;
use strict;
use warnings;

use List::MoreUtils qw(uniq);

use base qw(LSW::Dictionary::DB::Base);

$LSW::Dictionary::DB::Queue::TTR = 3600;

sub check_or_create_tables {
    my $self = shift;

    my @q = (
        "
            -- mark new words to investigation
            CREATE TABLE IF NOT EXISTS WordsQueue (
                word VARCHAR(255) NOT NULL PRIMARY KEY,
                atime INTEGER NOT NULL
            )
        ",
        "
            CREATE INDEX IF NOT EXISTS idx_words_queue ON WordsQueue (atime DESC)
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
    return unless @$words;

    for my $w (uniq map {lc} @$words) {
        $class->instance->dbh->do(
            "INSERT OR IGNORE INTO WordsQueue(word, atime) VALUES (?, ?)",
            undef,
            $w, time
        );
    }

    return;
}

sub get {
    my ($class, $limit) = @_;
    $limit ||= 1;

    my $applicants = $class->instance->dbh->selectall_arrayref(
        "SELECT * FROM WordsQueue WHERE atime < ? LIMIT ?",
        { Slice => {} },
        time, $limit
    ) or die $class->instance->dbh->errstr;

    return [] unless @$applicants;

    my @words = ();
    for my $row (@$applicants) {
        # optimistic locking
        my $lock = $class->instance->dbh->do(
            "UPDATE WordsQueue SET atime = ? WHERE word = ? AND atime = ?",
            undef,
            time + $LSW::Dictionary::DB::Queue::TTR, $row->{word}, $row->{atime}
        );
        if (int $lock) {
            push @words, $row->{word};
        }
    }

    return \@words;
}

sub delete {
    my $class = shift;
    my $words = ref $_[0] eq "ARRAY" ? $_[0] : \@_;
    return unless @$words;

    for my $w (uniq map {lc} @$words) {
        $class->instance->dbh->do(
            "DELETE FROM WordsQueue WHERE word = ?",
            undef,
            $w
        );
    }

    return;
}

1;
__END__
