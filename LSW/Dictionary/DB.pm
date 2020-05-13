package LSW::Dictionary::DB;
use strict;
use warnings;

use Module::Util qw();
use Module::Load qw();

for ( Module::Util::find_in_namespace(__PACKAGE__) ) {
    next if /::Base$/;
    Module::Load::load($_) unless Module::Util::module_is_loaded($_);
}

sub words()  { __PACKAGE__ . "::Words" }
sub sounds() { __PACKAGE__ . "::Sounds" }
sub trash()  { __PACKAGE__ . "::Trash" }
sub queue()  { __PACKAGE__ . "::Queue" }

1;
__END__
