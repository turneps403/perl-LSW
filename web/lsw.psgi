use strict;
use warnings;

use JSON::XS qw();
use Cwd qw();
use File::Spec;
use MIME::Types;
use Plack::Request;
use Plack::Builder;
use Plack::App::File;

use LSW::Log;
use LSW::Dictionary;

use File::Basename;
my $static_prefix = File::Spec->catdir(dirname(__FILE__), "static");
my $LSW = LSW::Dictionary->new(db_folder => $ENV{LSW_DB_FOLDER}, queue_enable => 1);


sub static {
    my $req = shift;
    my $res = $req->new_response(200);

    my $path_info = $req->path_info;
    $path_info = "/index.html" if $path_info eq "/";
    $path_info = File::Spec->catfile($static_prefix, $path_info);
    log_dbg("Try to \$path_info =", $path_info);

    my $file = Cwd::realpath($path_info);
    die "No file by path ".$req->path_info unless $file and -f $file;

    die "No file by path ".$req->path_info unless index($file, $static_prefix."/") == 0;

    my $mime = MIME::Types->new->mimeTypeOf($file);
    die "No file by path ".$req->path_info unless $mime;

    open(IND, "<", $file);
    my $content = join('', <IND>);
    close(IND);

    $res->content_type($mime);
    $res->body($content);
    return $res;
}

sub pong {
    my $req = shift;
    my $res = $req->new_response(200);
    my $pong = lc $req->parameters->{pong};
    $res->body({ pong => $pong });
    return $res;
}

sub translate {
    my $req = shift;
    my $res = $req->new_response(200);
    my $content = lc $req->parameters->{text_to_translate};

    my @words = $content =~ /(\w{1,240})/g;
    log_info("Try to resolve words:", \@words);

    my $ipa_dict = $LSW->db_lookup(\@words);

    $content =~ s/(\w{1,240})/$ipa_dict->{$1} ? "$1 (".$ipa_dict->{$1}->{ipa}.")" : "-$1-"/seg;

    $res->body({ ret => $content });
    return $res;
}

sub add_word {
    # my $req = shift;
    # my $res = $req->new_response(200);
    # my $query = lc $req->parameters->{word};
    # $res->content_type("text/plain");
    # $res->body($query);
    # return $res;
}

my $home_router = [
    [ "/" => \&static ],
    [ qr/^\/(img|js|css)\// => \&static ],
    [ "/add" => \&add_word ],
    [ "/translate" => \&translate ],
    [ "/ping" => \&pong ]
];

my $app = sub {
    my $env = shift;

    my $req = Plack::Request->new($env);

    my $code = undef;
    my $path_info = $req->path_info;
    for my $desc (@$home_router) {
        unless (ref $desc->[0]) {
            if ($path_info eq $desc->[0]) {
                $code = $desc->[1];
                last;
            }
        } else {
            if ($path_info =~ $desc->[0]) {
                $code = $desc->[1];
                last;
            }
        }
    }

    if ($code) {
        my $res = eval { $code->($req) };
        if ($@) {
            # TODO: yep, this is unacceptable for production
            log_error("Fail:", $@);
            my $res = $req->new_response(500);
            $res->content_type("text/plain");
            $res->body($@);
        }
        if (ref $res->body eq "HASH" or ref $res->body eq "ARRAY") {
            $res->content_type("application/json");
            $res->body( JSON::XS->new->encode($res->body) );
        }
        $res->finalize;
    } else {
        my $res = $req->new_response(404);
        $res->content_type("text/html");
        $res->body("404 Not Found");
        $res->finalize;
    }
};

# LSW_DB_FOLDER=~/tmp/lsw plackup -I lib web/lsw.psgi
