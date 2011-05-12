package Protocol::WebSocket::Frame;

use strict;
use warnings;

use Encode ();
use Scalar::Util 'readonly';

sub new {
    my $class = shift;
    $class = ref $class if ref $class;
    my $buffer = shift;

    my $self = {@_};
    bless $self, $class;

    $buffer = '' unless defined $buffer;

    if (Encode::is_utf8($buffer)) {
        $self->{buffer} = Encode::encode('UTF_8', $buffer);
    }
    else {
        $self->{buffer} = $buffer;
    }

    return $self;
}

sub append {
    my $self = shift;

    return unless defined $_[0];

    $self->{buffer} .= $_[0];
    $_[0] = '' unless readonly $_[0];

    return $self;
}

sub next {
    my $self = shift;

    my $bytes = $self->next_bytes;
    return unless defined $bytes;

    return Encode::decode('UTF-8', $bytes);
}

sub next_bytes {
    my $self = shift;

    return unless $self->{buffer} =~ s/^[^\x00]*\x00(.*?)\xff//s;

    return $1;
}

sub to_bytes {
    my $self = shift;

    return "\x00" . $self->{buffer} . "\xff";
}

sub to_string {
    my $self = shift;

    return "\x00" . Encode::decode('UTF-8', $self->{buffer}) . "\xff";
}

1;
__END__

=head1 NAME

Protocol::WebSocket::Frame - WebSocket Frame

=head1 SYNOPSIS

    # Create frame
    my $frame = Protocol::WebSocket::Frame->new('123');
    $frame->to_string; # \x00123\xff

    # Parse frames
    my $frame = Protocol::WebSocket::Frame->new;
    $frame->append("123\x00foo\xff56\x00bar\xff789");
    $f->next; # foo
    $f->next; # bar

=head1 DESCRIPTION

Construct or parse a WebSocket frame.

=head1 METHODS

=head2 C<new>

Create a new L<Protocol::WebSocket::Frame> instance. Automatically detect if the
passed data is a Perl string or bytes.

=head2 C<append>

    $frame->append("\x00foo");
    $frame->append("bar\xff");

Append a frame chunk.

=head2 C<next>

    $frame->append("\x00foo");
    $frame->append("\xff\x00bar\xff");

    $frame->next; # foo
    $frame->next; # bar

Return the next frame as a Perl string.

=head2 C<next_bytes>

Return the next frame as a UTF-8 encoded string.

=head2 C<to_string>

    my $frame = Protocol::WebSocket::Frame->new('foo');
    $frame->to_string; # \x00foo\xff

Construct a WebSocket frame as a Perl string.

=head2 C<to_bytes>

Construct a WebSocket frame as a UTF-8 encoded string.

=cut
