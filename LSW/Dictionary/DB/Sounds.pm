package LSW::Dictionary::DB::Sounds;
use strict;
use warnings;

use String::CRC32 qw();
use Digest::MD5 qw();

use base qw(LSW::Dictionary::DB::Base);

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
            CREATE INDEX IF NOT EXISTS idx_sounds_crc ON Sounds (crc, status);
        ",
        "
            CREATE INDEX IF NOT EXISTS idx_sounds_status ON Sounds (status)
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
            "SELECT crc, md5 FROM Sounds WHERE crc IN (".join(",", ('?')x@chunk).") AND status = 1",
            { Slice => {} },
            @chunk
        ) or die $class->instance->dbh->errstr;
        for (@$tmp_res) {
            $res->{ $_->{crc} } ||= [];
            push @{ $res->{ $_->{crc} } }, $_;
        }
    }

    my $ret = {};
    for my $crc (keys %$lcmap) {
        for my $source_word (@{ $lcmap->{$crc} }) {
            if ($res->{$crc}) {
                $ret->{$source_word} = $res->{$crc};
            } else {
                # empty array for not founded word
                $ret->{$source_word} = [];
            }
        }
    }

    return $ret;
}

sub add {
    my ($class, $resolved) = @_;
    return unless $resolved and %$resolved;

    for my $res (values %$resolved) {
        if ($res->{sounds} and @{$res->{sounds}}) {
            for my $sound_desc (@{$res->{sounds}}) {
                $class->instance->dbh->do(
                    "INSERT OR IGNORE INTO Sounds(md5, crc, sound_url, status) VALUES (?, ?, ?, 0)",
                    undef,
                    Digest::MD5::md5_hex($res->{crc} . $sound_desc->{sound_url}), $res->{crc}, $sound_desc->{sound_url}
                );
            }
        }
    }

    return;
}

1;
__END__
