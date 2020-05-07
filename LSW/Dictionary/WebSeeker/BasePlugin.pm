package LSW::Dictionary::WebSeeker::BasePlugin;
use strict;
use warnings;

sub weight {
    die "Not implemented!";
}

sub create_urls {
    my $class = shift;
    my $words = ref $_[0] == "ARRAY" ? $_[0] : \@_;
    # need to be returned in the same order
    # return as array, not ref!
    die "Not implemented!";
}

sub urls_per_loop {
    return 3;
}

sub process_dom {
    my ($class, $libxml_dom) = @_;
    die "Not implemented!";
}

1;
__END__
