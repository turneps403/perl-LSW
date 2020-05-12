package LSW::Dictionary::DB;
use strict;
use warnings;

use LSW::Dictionary::DB::Words qw();
use LSW::Dictionary::DB::Sounds qw();

sub words()  { "LSW::Dictionary::DB::Words" }
sub sounds() { "LSW::Dictionary::DB::Sounds" }

1;
__END__
