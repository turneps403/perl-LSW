package LSW::Dictionary;
use Mouse;

use LSW::Dictionary::DB qw();
use LSW::Dictionary::WebSeeker qw();


sub BUILDARGS {
    my $class = shift;
    my $params = @_ == 1 ? $_[0] : {@_};
    if ($params->{db_path}) {
        $params->{db} = LSW::Dictionary::DB->new(db_path => $params->{db_path});
    }
    return $params;
}


has 'db' => (
    is => 'ro',
    isa => 'Maybe[LSW::Dictionary::DB]',
    required => 1
);

has 'web_seeker' => (
    is => 'ro',
    isa => 'ClassName',
    lazy => 1,
    default => sub { "LSW::Dictionary::WebSeeker" }
);

sub words2ipa {
    my $self = shift;
    return unless @_;
    my $params = {};
    if (ref $_[-1] eq 'HASH') {
        $params = pop(@_);
    }
    return unless @_;
    my $words = ref $_[0] eq "ARRAY" ? $_[0] : \@_;

    my $db_words = $self->db->get_words($words);
    if (%$db_words) {
        my $sounds = $self->db->get_sounds(keys %$db_words);
        # TODO
    }

    my @not_db_words = grep { not exists $db_words->{$_} } @$words;
    my $db_words = $self->web_seeker->get_words(@not_db_words);


}

no Mouse;
__PACKAGE__->meta->make_immutable;
1;
__END__
