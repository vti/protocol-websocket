package Protocol::WebSocket::Message;

use strict;
use warnings;

use base 'Protocol::WebSocket::Stateful';

sub new {
    my $class = shift;
    $class = ref $class if ref $class;

    my $self = {@_};
    bless $self, $class;

    $self->version(76) unless $self->version;

    $self->{buffer} = '';

    $self->{fields} ||= {};

    return $self;
}

sub fields { shift->{fields} }

sub error {
    my $self = shift;

    return $self->{error} unless @_;

    my $error = shift;
    $self->{error} = $error;
    $self->state('error');

    return $self;
}

sub challenge { @_ > 1 ? $_[0]->{challenge} = $_[1] : $_[0]->{challenge} }

sub version { @_ > 1 ? $_[0]->{version} = $_[1] : $_[0]->{version} }

1;
