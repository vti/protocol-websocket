package Protocol::WebSocket::Handshake::Server;

use strict;
use warnings;

use base 'Protocol::WebSocket::Handshake';

sub parse {
    my $self  = shift;
    my $chunk = shift;

    my $req = $self->req;
    my $res = $self->res;

    unless ($req->is_done) {
        unless ($req->parse($chunk)) {
            $self->error($req->error);
            return;
        }

        if ($req->is_done) {
            $res->version($req->version);
            $res->host($req->host);

            #$res->secure($req->secure);
            $res->resource_name($req->resource_name);
            $res->origin($req->origin);

            if ($req->version > 75) {
                $res->number1($req->number1);
                $res->number2($req->number2);
                $res->challenge($req->challenge);
            }
        }
    }

    return 1;
}

sub is_done   { shift->req->is_done }
sub to_string { shift->res->to_string }

1;
