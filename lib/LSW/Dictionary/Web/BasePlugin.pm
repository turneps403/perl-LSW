package LSW::Dictionary::Web::BasePlugin;
use strict;
use warnings;

sub create_url {
    my ($class, $word) = @_;
    die "Not implemented!";
}

sub parse {
    my ($class, $libxml_dom) = @_;
    die "Not implemented!";
}

sub weight { 1 }

1;
__END__
