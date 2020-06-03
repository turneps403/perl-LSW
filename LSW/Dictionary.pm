package LSW::Dictionary;
use strict;
use warnings;

use List::MoreUtils qw(uniq);
use LSW::Dictionary::DB qw();
use LSW::Dictionary::Web qw();

sub new {
    my $class = shift;
    my $params = @_ == 1 ? $_[0] : {@_};
    # words_db_path is a dafault database
    LSW::Dictionary::DB->words->init($params->{words_db_path});
    LSW::Dictionary::DB->words->init($params->{fk_db_path} || $params->{words_db_path});
    LSW::Dictionary::DB->sounds->init($params->{sounds_db_path} || $params->{words_db_path});
    LSW::Dictionary::DB->trash->init($params->{trash_db_path} || $params->{words_db_path});
    LSW::Dictionary::DB->queue->init($params->{queue_db_path} || $params->{words_db_path});
    return bless {}, $class;
}

sub db() { "LSW::Dictionary::DB" }
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

    return $self->db->lookup($words, {queue_enable => 1});
}


1;
__END__
