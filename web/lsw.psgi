use strict;
use warnings;

use Cwd qw();
use File::Spec;
use MIME::Types;
use Plack::Request;
use Plack::Builder;
use Plack::App::File;

use LSW::Log;

use File::Basename;
my $static_prefix = File::Spec->catdir(dirname(__FILE__), "static");

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

sub add_word {
    my $req = shift;
    my $res = $req->new_response(200);
    my $query = lc $req->parameters->{word};
    $res->content_type("text/plain");
    $res->body($query);
    return $res;
}

my $home_router = [
    [ "/" => \&static ],
    [ qr/^\/(img|js|css)\// => \&static ],
    [ "add" => \&add_word ]
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
        $res->finalize;
    } else {
        my $res = $req->new_response(404);
        $res->content_type("text/html");
        $res->body("404 Not Found");
        $res->finalize;
    }
};

# plackup -I lib  web/lsw.psgi
