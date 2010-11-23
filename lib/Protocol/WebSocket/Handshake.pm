package Protocol::WebSocket::Handshake;

use strict;
use warnings;

use Protocol::WebSocket::Request;
use Protocol::WebSocket::Response;

sub new {
    my $class = shift;
    $class = ref $class if ref $class;

    my $self = {@_};
    bless $self, $class;

    return $self;
}

sub secure { shift->{secure} }

sub error { shift->{error} }

sub req { shift->{req} ||= Protocol::WebSocket::Request->new }
sub res { shift->{res} ||= Protocol::WebSocket::Response->new }

1;
