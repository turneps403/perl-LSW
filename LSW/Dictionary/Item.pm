package LSW::Dictionary::Item;
use Mouse;

has 'word' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
    documentation => "word in lower cause"
);

has 'ipa' => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => sub { '' },
    documentation => "international phonetic alphabet"
);

has 'sounds' => (
    is => 'rw',
    isa => 'ArrayRef[Str]',
    lazy => 1,
    default => sub { [] },
    documentation => "list of file names"
);

has 'fk' => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => sub { '' },
    documentation => "prime form of a word that could be found"
);

no Mouse;
__PACKAGE__->meta->make_immutable;
1;
__END__
