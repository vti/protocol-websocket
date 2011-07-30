package Protocol::WebSocket::Handshake::Server;

use strict;
use warnings;

use base 'Protocol::WebSocket::Handshake';

use Protocol::WebSocket::Request;

sub new_from_psgi {
    my $class = shift;

    my $req = Protocol::WebSocket::Request->new_from_psgi(@_);
    my $self = $class->new(req => $req);

    return $self;
}

sub parse {
    my $self = shift;

    my $req = $self->req;
    my $res = $self->res;

    return 1 if $req->is_done;

    unless ($req->parse($_[0])) {
        $self->error($req->error);
        return;
    }

    return 1 unless $req->is_done;

    $res->version($req->version);
    $res->host($req->host);

    $res->secure($req->secure);
    $res->resource_name($req->resource_name);
    $res->origin($req->origin);

    if ($req->version eq 'draft-ietf-hybi-00') {
        $res->number1($req->number1);
        $res->number2($req->number2);
        $res->challenge($req->challenge);
    }
    elsif ($req->version eq 'draft-ietf-hybi-10') {
        $res->key($req->key);
    }

    return 1;
}

sub is_done   { shift->req->is_done }
sub to_string { shift->res->to_string }

1;
__END__

=head1 NAME

Protocol::WebSocket::Handshake::Server - WebSocket Server Handshake

=head1 SYNOPSIS

    my $h = Protocol::WebSocket::Handshake::Server->new;

    # Parse client request
    $h->parse(<<"EOF");
        WebSocket HTTP message
    EOF

    $h->error;   # Check if there were any errors
    $h->is_done; # Returns 1

    # Create response
    $h->to_string;

=head1 DESCRIPTION

Construct or parse a server WebSocket handshake. This module is written for
convenience, since using request and response directly requires the same code
again and again.

=head1 METHODS

=head2 C<new>

Create a new L<Protocol::WebSocket::Handshake::Server> instance.

=head2 C<new_from_psgi>

    my $env = {
        HTTP_HOST => 'example.com',
        HTTP_CONNECTION => 'Upgrade',
        ...
    };
    my $handshake = Protocol::WebSocket::Handshake::Server->new_from_psgi($env);

Create a new L<Protocol::WebSocket::Handshake::Server> instance from L<PSGI>
environment.

=head2 C<parse>

    $handshake->parse($buffer);
    $handshake->parse($handle);

Parse a WebSocket client request. Returns C<undef> and sets C<error> attribute
on error.

When buffer is passed it's modified (unless readonly).

=head2 C<to_string>

Construct a WebSocket server response.

=head2 C<is_done>

Check whether handshake is done.

=cut
