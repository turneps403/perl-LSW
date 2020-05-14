package LSW::Dictionary;
use Mouse;

use List::MoreUtils qw(uniq);
use LSW::Dictionary::DB qw();
use LSW::Dictionary::Web qw();
#use LSW::Dictionary::WebSeeker qw();


sub BUILDARGS {
    my $class = shift;
    my $params = @_ == 1 ? $_[0] : {@_};
    LSW::Dictionary::DB->words->init($params->{words_db_path});
    LSW::Dictionary::DB->sounds->init($params->{sounds_db_path});
    LSW::Dictionary::DB->trash->init($params->{trash_db_path});
    LSW::Dictionary::DB->queue->init($params->{queue_db_path});
    return $params;
}


has 'db' => (
    is => 'ro',
    isa => 'ClassName',
    lazy => 1,
    default => sub { "LSW::Dictionary::DB" }
);

has 'web_seeker' => (
    is => 'ro',
    isa => 'ClassName',
    lazy => 1,
    default => sub { "LSW::Dictionary::WebSeeker" }
);

sub web() { "LSW::Dictionary::Web" }

sub lookup {
    my $self = shift;
    return unless @_;
    my $params = {};
    if (ref $_[-1] eq 'HASH') {
        $params = pop(@_);
    }
    return unless @_;
    my $words = ref $_[0] eq "ARRAY" ? $_[0] : \@_;

    my $db_words = $self->db->words->lookup($words);
    my $db_sounds = $self->db->sounds->lookup($words);

    my $ret = {};
    for my $w (@$words) {
        $ret->{$w} = $db_words->{$w};
        if (@{$db_sounds->{$w}}) {
            $ret->{$w}->{sounds} = $db_sounds->{$w};
        }
    }

    my @not_found = grep { not %{ $ret->{$_} } } keys %$db_words;
    if (@not_found) {
        my $db_trash = $self->db->trash->lookup(@not_found);
        my @new_words = grep { not $db_trash->{$_} } @not_found;
        if (@new_words) {
            if ($params->{resolve_immediately}) {
                my $resolved_words = $self->web->resolve(@new_words);
                my @trash = grep {not $resolved_words->{$_}} @new_words;
                if (@trash) {
                    $self->db->trash->add(@trash);
                }
                if (%$resolved_words) {
                    $self->db->words->add($resolved_words);
                    $self->db->sounds->add($resolved_words);
                }
                $self->db->queue->delete(@new_words);
                for my $new_w (keys %$resolved_words) {
                    # TODO: remember to not translate sounds of new words
                    $ret->{$new_w} = {
                        sounds => [],
                        map { +($_ => $resolved_words->{$_}) } qw(crc word ipa fk)
                    };
                }
            } else {
                $self->db->queue->add(@new_words);
            }
        }
    }

    return $ret;
}

# sub auto_resolve {
#     my ($class, $limit) = @_;
#     $limit ||= 3;
#     LSW::Dictionary::DB->queue->
#
# }

no Mouse;
__PACKAGE__->meta->make_immutable;
1;
__END__
