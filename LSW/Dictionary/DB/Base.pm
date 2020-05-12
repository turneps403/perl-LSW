package LSW::Dictionary::DB::Base;
use strict;
use warnings;

use DBI qw();

my $singletones = {};

END {
    for my $instance (values %$singletones) {
        if ($instance->{dbh}) {
            $instance->{dbh}->disconnect;
            undef $instance->{dbh};
        }
    }
}

sub init {
    my ($class, $db_path) = @_;
    if ($db_path) {
        if (not $singletones->{$class} or $singletones->{$class}->{db_path} eq $db_path) {
            # one path on a class
            $singletones->{$class}->{db_path} = $db_path;
        } else {
            die "$class: $db_path cant be accepted\n";
        }
    } else {
        die "Try to init db $class without db_path\n";
    }
    return;
}

sub instance {
    my $class = shift;
    unless ($singletones->{$class}) {
        die "$class doesnt have db_path definition. use init first\n";
    } elsif (ref $singletones->{$class} eq "HASH") {
        $singletones->{$class} = $class->_new();
        $singletones->{$class}->check_or_create_tables;
        return $singletones->{$class};
    } else {
        if ($singletones->{$class}->last_ping + 5 > time) {
            return $singletones->{$class};
        } elsif ($singletones->{$class}->dbh->ping) {
            $singletones->{$class}->last_ping(time);
            return $singletones->{$class};
        } else {
            $singletones->{$class}->dbh->disconnect;
            delete $singletones->{$class}->{dbh};
            $singletones->{$class} = $class->_new();
            return $singletones->{$class};
        }
    }
}

sub _new {
    my $class = shift;

    my $dbh = DBI->connect(
        sprintf("DBI:SQLite:database=%s", $singletones->{$class}->{db_path}),
        "", "",
        {
            AutoCommit => 1,
            RaiseError => 1
        }
    ) or die $DBI::errstr;
    $dbh->{sqlite_see_if_its_a_number} = 1;

    my $self = bless { dbh => $dbh, db_path => $singletones->{$class}->{db_path}, last_ping => time }, $class;

    return $self;
}

sub dbh { shift->{dbh} }
sub last_ping {
    my $self = shift;
    if (@_) {
        $self->{last_ping} = $_[0];
    }
    return $self->{last_ping};
}

sub check_or_create_tables {
    my $instance = shift;
    die "Not implemented!\n";
}

1;
__END__
