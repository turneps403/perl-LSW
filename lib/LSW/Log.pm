package LSW::Log;
use strict;
use warnings;

use Data::Dumper qw();
use Exporter qw(import);
our @EXPORT = qw(log_error log_warn log_info log_dbg log_debug);

my $weights = {};
@$weights{ qw(error warn info debug) } = (1..4);

#$LSW::Log::level = "info"; # to override later with 'local' type
$LSW::Log::level = "debug";

sub log_debug { _log("debug", @_) }
sub log_info  { _log("info", @_) }
sub log_warn  { _log("warn", @_) }
sub log_error { _log("error", @_) }

*log_dbg = \&log_debug;

sub _log {
    my $level = shift;
    if ($weights->{$LSW::Log::level} < $weights->{$level}) {
        return;
    }

    my ($pkg, $line) = (caller(1))[0, 2];

    local $Data::Dumper::Indent = 0;
    my @args = ();
    for (@_) {
        if (ref $_) {
            # just remove '$VAR1 = ' and ';'
            push @args, substr(Data::Dumper::Dumper($_), 8, -1);
        } else {
            push @args, defined $_ ? $_ : 'undef';
        }
    }

    my $log_str = sprintf(
        '%s [%d:%s] %s (%s at line %d)%s',
        scalar localtime time,
        $$,
        $level,
        join(' ', @args),
        $pkg,
        $line,
        "\n"
    );
    print STDERR $log_str;
    return;
}

1;
__END__
