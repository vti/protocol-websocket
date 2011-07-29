package Protocol::WebSocket::Frame;

use strict;
use warnings;

use Encode ();
use Scalar::Util 'readonly';

sub new {
    my $class = shift;
    $class = ref $class if ref $class;
    my $buffer;

    if (@_ == 1) {
        $buffer = shift @_;
    }
    else {
        my %args = @_;
        $buffer = delete $args{buffer};
    }

    my $self = {@_};
    bless $self, $class;

    $buffer = '' unless defined $buffer;

    if (Encode::is_utf8($buffer)) {
        $self->{buffer} = Encode::encode('UTF-8', $buffer);
    }
    else {
        $self->{buffer} = $buffer;
    }

    $self->{version} ||= 'draft-ietf-hidy-10';

    $self->{fragments} = [];

    return $self;
}

sub version {
    my $self = shift;

    return $self->{version};
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

sub fin    { @_ > 1 ? $_[0]->{fin}    = $_[1] : $_[0]->{fin} }
sub rsv    { @_ > 1 ? $_[0]->{rsv}    = $_[1] : $_[0]->{rsv} }
sub opcode { @_ > 1 ? $_[0]->{opcode} = $_[1] : $_[0]->{opcode} }
sub masked { @_ > 1 ? $_[0]->{masked} = $_[1] : $_[0]->{masked} }

sub next_bytes {
    my $self = shift;

    if (   $self->version eq 'draft-hixie-75'
        || $self->version eq 'draft-ietf-hybi-00')
    {
        return unless $self->{buffer} =~ s/^[^\x00]*\x00(.*?)\xff//s;

        return $1;
    }

    return unless length $self->{buffer} >= 2;

    my $hdr = substr($self->{buffer}, 0, 1);

    my @bits = split //, unpack("B*", $hdr);

    $self->fin($bits[0]);
    $self->rsv([@bits[1..3]]);

    if (!@{$self->{fragments}}) {
        my $opcode = unpack 'C', pack 'B*', '0000' . join '', @bits[4 .. 7];
        $self->opcode($opcode);
    }

    my $offset = 1; # FIN,RSV[1-3],OPCODE

    my $payload_len = unpack 'C', substr($self->{buffer}, 1, 1);

    my $masked = ($payload_len & 2 ** 7) >> 7;
    $self->masked($masked);

    $offset += 1; # + MASKED,PAYLOAD_LEN

    $payload_len = $payload_len & 2 ** 7 - 1;
    if ($payload_len == 126) {
        return unless length ($self->{buffer}) >= $offset + 2;

        $payload_len = unpack 'S', substr($self->{buffer}, $offset, 2);

        $offset += 2;
    }
    elsif ($payload_len > 126) {
        return unless length ($self->{buffer}) >= $offset + 4;

        my $bits = join '', map { unpack 'B*' } split //,
          substr($self->{buffer}, $offset, 8);
        $bits =~ s{^.}{0};            # Most significant bit must be 0
        $bits = substr($bits, 32);    # TODO how to handle bigger numbers?
        $payload_len = unpack 'N', pack 'B*', $bits;

        $offset += 8;
    }

    my $mask;
    if ($self->masked) {
        return unless length ($self->{buffer}) >= $offset + 4;

        $mask = substr($self->{buffer}, $offset, 4);
        $offset += 4;
    }

    return if length($self->{buffer}) < $offset + $payload_len;

    my $payload = substr($self->{buffer}, $offset);

    if ($self->masked) {
        $payload = $self->_mask($payload, $mask);
    }

    $self->{buffer} = '';

    if ($self->fin) {
        $payload = join '', @{$self->{fragments}}, $payload;
        $self->{fragments} = [];
        return $payload;
    }
    else {
        push @{$self->{fragments}}, $payload;
    }

    return;
}

sub to_bytes {
    my $self = shift;

    if (   $self->version eq 'draft-hixie-75'
        || $self->version eq 'draft-ietf-hybi-00')
    {
        return "\x00" . $self->{buffer} . "\xff";
    }

    my $string = '';

    my $opcode = $self->opcode || 1;
    $string .= pack 'C', ($opcode + 128);

    my $payload_len = length($self->{buffer});
    if ($payload_len <= 125) {
        # TODO mask
        $payload_len += 128 if $self->masked;
        $string .= pack 'C', $payload_len;
    }
    elsif ($payload_len <= 2 ** 15) {
        $string .= pack 'C', 126 + ($self->masked ? 128 : 0);
        $string .= pack 'n', $payload_len;
    }
    else {
        $string .= pack 'C', 127 + ($self->masked ? 128 : 0);

        # 8 octets
        $string .= pack 'N', 0;
        $string .= pack 'N', $payload_len;
    }

    if ($self->masked) {
        my $mask = $self->{mask} || rand(2 ** 32); # Not sure if perl provides
                                                   # good randomness
        $mask = pack 'N', $mask;

        $string .= $mask;
        # TODO

        $string .= $self->_mask($self->{buffer}, $mask);
    }
    else {
        $string .= $self->{buffer};
    }

    return $string;
}

sub to_string {
    my $self = shift;

    die 'DO NOT USE';

    if (   $self->version eq 'draft-hixie-75'
        || $self->version eq 'draft-ietf-hybi-00')
    {
        return "\x00" . Encode::decode('UTF-8', $self->{buffer}) . "\xff";
    }
}

sub _mask {
    my $self = shift;
    my ($payload, $mask) = @_;

    my @mask = split //, $mask;

    my @payload = split //, $payload;
    for (my $i = 0; $i < @payload; $i++) {
        my $j = $i % 4;
        $payload[$i] ^= $mask[$j];
    }

    return join '', @payload;
}

1;
__END__

=head1 NAME

Protocol::WebSocket::Frame - WebSocket Frame

=head1 SYNOPSIS

    # Create frame
    my $frame = Protocol::WebSocket::Frame->new('123');
    $frame->to_bytes; # \x00123\xff

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

=head2 C<to_bytes>

Construct a WebSocket frame as a UTF-8 encoded string.

=cut
