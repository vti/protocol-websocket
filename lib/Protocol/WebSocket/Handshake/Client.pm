package Protocol::WebSocket::Handshake::Client;

use strict;
use warnings;

use base 'Protocol::WebSocket::Handshake';

use Protocol::WebSocket::URL;

sub new {
    my $self = shift->SUPER::new(@_);

    $self->_build_url($self->{url});

    return $self;
}

sub url {
    my $self = shift;
    my $url  = shift;

    return $self->{url} unless $url;

    $self->_set_url($url);

    return $self;
}

sub parse {
    my $self  = shift;
    my $chunk = shift;

    my $req = $self->req;
    my $res = $self->res;

    unless ($res->is_done) {
        unless ($res->parse($chunk)) {
            $self->error($res->error);
            return;
        }

        if ($res->is_done) {
            if ($req->version > 75 && $req->checksum ne $res->checksum) {
                $self->error('Checksum is wrong.');
                return;
            }
        }
    }

    return 1;
}

sub is_done   { shift->res->is_done }
sub to_string { shift->req->to_string }

sub _build_url { Protocol::WebSocket::URL->new }

sub _set_url {
    my $self = shift;
    my $url  = shift;

    $url = $self->_build_url->parse($url) unless ref $url;

    my $req = $self->req;

    my $host = $url->host;
    $host .= ':' . $url->port if defined $url->port;
    $req->host($host);

    $req->resource_name($url->resource_name);

    return $self;
}

1;
