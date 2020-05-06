package LSW::Dictionary::DB::Sound;
use strict;
use warnings;

sub new {
    my $class = shift;
    my $params = ref $_[0] eq 'HASH' ? $_[0] : {@_};

    my $self = bless {}, $class;
    for (qw(crc sound_url source lang)) {
        if (exists $params->{$_}) {
            $self->$_($params->{$_});
        }
    }

    return $self;
}

sub crc { shift->_acc('crc', @_) }
sub sound_url { shift->_acc('sound_url', @_) }
sub source { shift->_acc('source', @_) }
sub lang { shift->_acc('lang', @_) }

sub _acc {
    my $self = shift;
    my $field_name = shift;
    if (@_) {
        $self->{$field_name} = $_[0];
        return;
    } else {
        return $self->{$field_name};
    }
}

sub save {
    my $self = shift;
    return if $self->num;

    LSW::Dictionary::DB->instance->do(
        "REPLACE INTO Words (crc, sound_url, source, lang)
        VALUES(?, ?, ?, ?)",
        map { $self->$_ } qw(crc sound_url source lang)
    );


    return;
}


1;
package LSW::Dictionary::DB::Word;
use strict;
use warnings;

sub new {
    my $class = shift;
    my $params = ref $_[0] eq 'HASH' ? $_[0] : {@_};

    my $self = bless {}, $class;
    for (qw(crc word ipa)) {
        if (exists $params->{$_}) {
            $self->$_($params->{$_});
        }
    }

    return $self;
}

sub src { shift->{src} }
sub ipa {
    my $self = shift;
    if (@_) {
        $self->{ipa} = $_[0];
        return;
    } else {
        return $self->{word};
    }
}
sub word {
    my $self = shift;
    if (@_) {
        $self->{word} = $_[0];
        unless ($self->{crc}) {
            $self->{crc} = String::CRC32::crc32(lc $_);
        }
        return;
    } else {
        return $self->{word};
    }
}

sub save {
    my $self = shift;
    return if $self->{_from_db};
    LSW::Dictionary::DB->instance->do(
        "REPLACE INTO Words (crc, word, ipa) VALUES(?, ?, ?)",
        map { $self->$_ } qw(crc word ipa)
    );
    return;
}

1;
package LSW::Dictionary::DB;
use strict;
use warnings;

use DBI qw();
use String::CRC32 qw();

my $db_path = undef;
my $singletone = undef;
my $last_ping = 0;

sub init {
    my $class = shift;
    $db_path ||= shift;
    return;
}

sub instance {
    my $class = shift;
    unless ($singletone) {
        return ($singletone = $class->new($db_path));
    } else {
        if ($last_ping + 5 < time and $singletone->dbh->ping) {
            $last_ping = time;
            return $singletone;
        }
        $singletone = undef;
        return $class->instance;
    }
}

sub new {
    my $class = shift;
    my $params = @_ == 1 ? $_[0] : {@_};

    return unless $params->{db_path};

    my $dbh = DBI->connect(
        sprintf("DBI:SQLite:database=%s", $params->{db_path}),
        "", "",
        {
            AutoCommit => 1,
            RaiseError => 1
        }
    ) or die $DBI::errstr;
    $dbh->{sqlite_see_if_its_a_number} = 1;

    my $self = bless { dbh => $dbh }, $class;
    $self->check_or_create_tables;

    return $self;
}

sub dbh { shift->{dbh} }

sub check_or_create_tables {
    my $self = shift;

    $dbh->do("
        CREATE TABLE IF NOT EXISTS Words (
        	crc INTEGER PRIMARY KEY,
            word VARCHAR(255) NOT NULL,
            ipa Text NOT NULL
        );

        CREATE TABLE IF NOT EXISTS Sounds (
        	crc INTEGER NOT NULL,
            sound_url Text NOT NULL,
            source INT NOT NULL,
            lang VARCHAR(255) NOT NULL,
            PRIMARY KEY (crc, sound_url)
        );
    ") or die "could not create tables...$!\n";

    return;
}

sub get_words {
    my $self = shift;
    my $words = ref $_[0] == "ARRAY" ? $_[0] : \@_;
    return {} unless @$words;

    # words can be not uniq
    my $crc_map = {};
    for (@$words) {
        my $crc = String::CRC32::crc32(lc $_);
        if (exists $crc_map->{ $crc }) {
            push @{ $crc_map->{ $crc } }, $_;
        } else {
            $crc_map->{ $crc } = [$_];
        }
    }

    my $ret = {};
    my @crc32 = keys %$crc_map;
    while (my @chunk = splice(@crc32, 0, 250)) {
        my $res = $self->dbh->selectall_arrayref(
            "SELECT * FROM Words WHERE crc IN (".join(",", ('?')x@chunk).")",
            { Slice => {} },
            @chunk
        ) or die $self->dbh->errstr;
        for my $row (@$res) {
            for ( @{ $crc_map->{$row->{crc}} } ) {
                $row->{_from_db} = 1;
                $ret->{ $_ } = LSW::Dictionary::DB::Word->new($row);
            }
        }
    }

    return $ret;
}

sub get_sounds {
    my $self = shift;
    my $words = ref $_[0] == "ARRAY" ? $_[0] : \@_;
    return {} unless @$words;

    # words can be not uniq
    my $crc_map = {};
    for (@$words) {
        my $crc = String::CRC32::crc32(lc $_);
        if (exists $crc_map->{ $crc }) {
            push @{ $crc_map->{ $crc } }, $_;
        } else {
            $crc_map->{ $crc } = [$_];
        }
    }

    my $ret = {};
    my @crc32 = keys %$crc_map;
    while (my @chunk = splice(@crc32, 0, 100)) {
        my $res = $self->dbh->selectall_arrayref(
            "SELECT * FROM Sounds WHERE crc IN (".join(",", ('?')x@chunk).")",
            { Slice => {} },
            @chunk
        ) or die $self->dbh->errstr;
        for my $row (@$res) {
            for ( @{ $crc_map->{$row->{crc}} } ) {
                $ret->{ $_ } ||= [];
                push @{$ret->{ $_ }}, LSW::Dictionary::DB::Sound->new($row);
            }
        }
    }

    return $ret;
}

1;
__END__
