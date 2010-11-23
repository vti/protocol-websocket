package Protocol::WebSocket::Response;

use strict;
use warnings;

use base 'Protocol::WebSocket::Message';

use Protocol::WebSocket::URL;
use Protocol::WebSocket::Cookie::Response;

use Digest::MD5 'md5';

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

sub number1   { @_ > 1 ? $_[0]->{number1}   = $_[1] : $_[0]->{number1} }
sub number2   { @_ > 1 ? $_[0]->{number2}   = $_[1] : $_[0]->{number2} }
sub challenge { @_ > 1 ? $_[0]->{challenge} = $_[1] : $_[0]->{challenge} }

sub checksum {
    my $self = shift;
    my $checksum = shift;

    if (defined $checksum) {
        $self->{checksum} = $checksum;
        return $self;
    }

    return $self->{checksum} if defined $self->{checksum};

    Carp::croak qq/number1 is required/   unless defined $self->number1;
    Carp::croak qq/number2 is required/   unless defined $self->number2;
    Carp::croak qq/challenge is required/ unless defined $self->challenge;

    $checksum = '';
    $checksum .= pack 'N' => $self->number1;
    $checksum .= pack 'N' => $self->number2;
    $checksum .= $self->challenge;
    $checksum = md5($checksum);

    return $self->{checksum} ||= $checksum;
}

sub cookies { @_ > 1 ? $_[0]->{cookies} = $_[1] : $_[0]->{cookies} }

sub cookie {
    my $self = shift;

    push @{$self->{cookies}},
      Protocol::WebSocket::Cookie::Response->new(@_);
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

        return $self->done if $self->finalize;

        $self->error('Not a valid response');
        return;
    }

    return 1;
}

sub finalize {
    my $self = shift;

    my $url = Protocol::WebSocket::URL->new;
    return unless $url->parse($self->location);

    $self->secure($url->secure);
    $self->host($url->host);
    $self->resource_name($url->resource_name);

    return 1;
}

sub to_string {
    my $self = shift;

    my $string = '';

    $string .= "HTTP/1.1 101 WebSocket Protocol Handshake\x0d\x0a";

    $string .= "Upgrade: WebSocket\x0d\x0a";
    $string .= "Connection: Upgrade\x0d\x0a";

    if ($self->version > 75) {
        Carp::croak qq/host is required/ unless defined $self->host;

        my $location = Protocol::WebSocket::URL->new(
            host          => $self->host,
            secure        => $self->secure,
            resource_name => $self->resource_name,
        );

        my $origin = $self->origin ? $self->origin : 'http://' . $location->host;
        $string .= 'Sec-WebSocket-Origin: ' . $origin . "\x0d\x0a";
        $string .= 'Sec-WebSocket-Location: ' . $location->to_string . "\x0d\x0a";
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

1;
