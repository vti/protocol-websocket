package Protocol::WebSocket::Message;

use strict;
use warnings;

use base 'Protocol::WebSocket::Stateful';

require Digest::MD5;

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

sub version { @_ > 1 ? $_[0]->{version} = $_[1] : $_[0]->{version} }

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

    Carp::croak(qq/number1 is required/)   unless defined $self->number1;
    Carp::croak(qq/number2 is required/)   unless defined $self->number2;
    Carp::croak(qq/challenge is required/) unless defined $self->challenge;

    $checksum = '';
    $checksum .= pack 'N' => $self->number1;
    $checksum .= pack 'N' => $self->number2;
    $checksum .= $self->challenge;
    $checksum = Digest::MD5::md5($checksum);

    return $self->{checksum} ||= $checksum;
}

sub _extract_number {
    my $self = shift;
    my $key  = shift;

    my $number = '';
    while ($key =~ m/(\d)/g) {
        $number .= $1;
    }
    $number = int($number);

    my $spaces = 0;
    while ($key =~ m/ /g) {
        $spaces++;
    }

    if ($spaces == 0) {
        return;
    }

    return int($number / $spaces);
}

1;
__END__

=head1 NAME

Protocol::WebSocket::Message - Base class for WebSocket request and response

=head1 DESCRIPTION

A base class for L<Protocol::WebSocket::Request> and
L<Protocol::WebSocket::Response>.

=head1 ATTRIBUTES

=head2 C<version>

=head2 C<fields>

=head2 C<error>

=head2 C<number1>

=head2 C<number2>

=head2 C<challenge>

=head1 METHODS

=head2 C<new>

Create a new L<Protocol::WebSocket::Message> instance.

=head2 C<checksum>

=cut
