package Protocol::WebSocket::Response;

use strict;
use warnings;

use base 'Protocol::WebSocket::Message';

use Protocol::WebSocket::URL;
use Protocol::WebSocket::Cookie::Response;

require Carp;

sub new {
    my $self = shift->SUPER::new(@_);

    $self->{cookies} ||= [];

    $self->{max_response_size} ||= 2048;

    $self->state('response_line');

    return $self;
}

sub origin {
    my $self = shift;

    unless (@_) {
        return $self->{fields}->{'Sec-WebSocket-Origin'}
          ||= delete $self->{origin};
    }

    $self->{fields}->{'Sec-WebSocket-Origin'} = shift;

    return $self;
}

sub location {
    my $self = shift;

    unless (@_) {
        return $self->{fields}->{'Sec-WebSocket-Location'}
          ||= delete $self->{location};
    }

    $self->{fields}->{'Sec-WebSocket-Location'} = shift;

    return $self;
}

sub host   { @_ > 1 ? $_[0]->{host}   = $_[1] : $_[0]->{host} }
sub secure { @_ > 1 ? $_[0]->{secure} = $_[1] : $_[0]->{secure} }

sub resource_name {
    @_ > 1 ? $_[0]->{resource_name} = $_[1] : $_[0]->{resource_name};
}

sub cookies { @_ > 1 ? $_[0]->{cookies} = $_[1] : $_[0]->{cookies} }

sub cookie {
    my $self = shift;

    push @{$self->{cookies}}, $self->_build_cookie(@_);
}

sub parse {
    my $self  = shift;
    my $chunk = shift;

    return 1 unless length $chunk;

    return if $self->error;

    $self->{buffer} .= $chunk;
    $chunk = $self->{buffer};

    if (length $chunk > $self->{max_response_size}) {
        $self->error('Request is too big');
        return;
    }

    while ($chunk =~ s/^(.*?)\x0d\x0a//) {
        my $line = $1;

        if ($self->state eq 'response_line') {
            unless ($line eq 'HTTP/1.1 101 WebSocket Protocol Handshake') {
                $self->error('Wrong response line');
                return;
            }

            $self->state('fields');
        }
        elsif ($line ne '') {
            my ($name, $value) = split ': ' => $line => 2;

            $self->fields->{$name} = $value;
        }
        else {
            $self->state('body');
        }
    }

    if ($self->state eq 'body') {
        if ($self->origin && $self->location) {
            return 1 if length $chunk < 16;

            if (length $chunk > 16) {
                $self->error('Body is too long');
                return;
            }

            $self->version(76);
            $self->checksum($chunk);
        }
        else {
            $self->version(75);
        }

        return $self->done if $self->_finalize;

        $self->error('Not a valid response');
        return;
    }

    return 1;
}

sub number1 { shift->_number('number1', 'key1', @_) }
sub number2 { shift->_number('number2', 'key2', @_) }

sub _number {
    my $self = shift;
    my ($name, $key, $value) = @_;

    my $method = "SUPER::$name";
    return $self->$method($value) if defined $value;

    $value = $self->$method();
    $value = $self->_extract_number($self->$key) if not defined $value;

    return $value;
}

sub key1 { @_ > 1 ? $_[0]->{key1} = $_[1] : $_[0]->{key1} }
sub key2 { @_ > 1 ? $_[0]->{key2} = $_[1] : $_[0]->{key2} }

sub to_string {
    my $self = shift;

    my $string = '';

    $string .= "HTTP/1.1 101 WebSocket Protocol Handshake\x0d\x0a";

    $string .= "Upgrade: WebSocket\x0d\x0a";
    $string .= "Connection: Upgrade\x0d\x0a";

    Carp::croak(qq/host is required/) unless defined $self->host;

    my $location = $self->_build_url(
        host          => $self->host,
        secure        => $self->secure,
        resource_name => $self->resource_name,
    );
    my $origin = $self->origin ? $self->origin : 'http://' . $location->host;

    if ($self->version <= 75) {
        $string .= 'WebSocket-Origin: ' . $origin . "\x0d\x0a";
        $string .= 'WebSocket-Location: ' . $location->to_string . "\x0d\x0a";
    }
    else {
        $string .= 'Sec-WebSocket-Origin: ' . $origin . "\x0d\x0a";
        $string
          .= 'Sec-WebSocket-Location: ' . $location->to_string . "\x0d\x0a";
    }

    if (@{$self->cookies}) {
        $string .= 'Set-Cookie: ';
        $string .= join ',' => $_->to_string for @{$self->cookies};
        $string .= "\x0d\x0a";
    }

    $string .= "\x0d\x0a";

    $string .= $self->checksum if $self->version > 75;

    return $string;
}

sub _finalize {
    my $self = shift;

    my $url = $self->_build_url;
    return unless $url->parse($self->location);

    $self->secure($url->secure);
    $self->host($url->host);
    $self->resource_name($url->resource_name);

    return 1;
}

sub _build_url    { shift; Protocol::WebSocket::URL->new(@_) }
sub _build_cookie { shift; Protocol::WebSocket::Cookie::Response->new(@_) }

1;
__END__

=head1 NAME

Protocol::WebSocket::Response - WebSocket Response

=head1 SYNOPSIS

    # Constructor

    # Parser

=head1 DESCRIPTION

Construct or parse a WebSocket response.

=head1 ATTRIBUTES

=head2 C<host>

=head2 C<location>

=head2 C<origin>

=head2 C<resource_name>

=head2 C<secure>

=head1 METHODS

=head2 C<new>

Create a new L<Protocol::WebSocket::Response> instance.

=head2 C<parse>

Parse a WebSocket response.

=head2 C<to_string>

Construct a WebSocket response.

=head2 C<cookie>

=head2 C<cookies>

=cut
