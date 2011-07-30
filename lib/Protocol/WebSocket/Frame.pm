package Protocol::WebSocket::Frame;

use strict;
use warnings;

use Config;
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

    $self->{max_fragments_amount} ||= 128;
    $self->{max_payload_size}     ||= 65536;

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

    while (length $self->{buffer}) {
        my $hdr = substr($self->{buffer}, 0, 1);

        my @bits = split //, unpack("B*", $hdr);

        $self->fin($bits[0]);
        $self->rsv([@bits[1 .. 3]]);

        my $opcode = unpack('C', $hdr) & 0b00001111;

        my $offset = 1;    # FIN,RSV[1-3],OPCODE

        my $payload_len = unpack 'C', substr($self->{buffer}, 1, 1);

        my $masked = ($payload_len & 0b10000000) >> 7;
        $self->masked($masked);

        $offset += 1;      # + MASKED,PAYLOAD_LEN

        $payload_len = $payload_len & 0b01111111;
        if ($payload_len == 126) {
            return unless length($self->{buffer}) >= $offset + 2;

            $payload_len = unpack 'n', substr($self->{buffer}, $offset, 2);

            $offset += 2;
        }
        elsif ($payload_len > 126) {
            return unless length($self->{buffer}) >= $offset + 4;

            my $bits = join '', map { unpack 'B*' } split //,
              substr($self->{buffer}, $offset, 8);

            # Most significant bit must be 0.
            # And here is a crazy way of doing it %)
            $bits =~ s{^.}{0};

            # Can we handle 64bit numbers?
            if ($Config{ivsize} <= 4) {
                $bits = substr($bits, 32);
                $payload_len = unpack 'N', pack 'B*', $bits;
            }

            # This is not tested :(
            else {
                $payload_len = unpack 'Q', pack 'B*', $bits;
            }

            $offset += 8;
        }

        if ($payload_len > $self->{max_payload_size}) {
            $self->{buffer} = '';
            die
              "Payload is too big. Deny big message or increase max_payload_size";
        }

        my $mask;
        if ($self->masked) {
            return unless length($self->{buffer}) >= $offset + 4;

            $mask = substr($self->{buffer}, $offset, 4);
            $offset += 4;
        }

        return if length($self->{buffer}) < $offset + $payload_len;

        my $payload = substr($self->{buffer}, $offset, $payload_len);

        if ($self->masked) {
            $payload = $self->_mask($payload, $mask);
        }

        substr($self->{buffer}, 0, $offset + $payload_len, '');

        # Injected control frame
        if (@{$self->{fragments}} && $opcode & 0b1000) {
            $self->opcode($opcode);
            return $payload;
        }

        if ($self->fin) {
            if (@{$self->{fragments}}) {
                $self->opcode(shift @{$self->{fragments}});
            }
            else {
                $self->opcode($opcode);
            }
            $payload = join '', @{$self->{fragments}}, $payload;
            $self->{fragments} = [];
            return $payload;
        }
        else {

            # Remember first fragment opcode
            if (!@{$self->{fragments}}) {
                push @{$self->{fragments}}, $opcode;
            }

            push @{$self->{fragments}}, $payload;

            die "Too many fragments"
              if @{$self->{fragments}} > $self->{max_fragments_amount};
        }
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

    if (length $self->{buffer} > $self->{max_payload_size}) {
        die
          "Payload is too big. Send shorter messages or increase max_payload_size";
    }

    my $string = '';

    my $opcode = $self->opcode || 1;
    $string .= pack 'C', ($opcode + 128);

    my $payload_len = length($self->{buffer});
    if ($payload_len <= 125) {
        $payload_len |= 0b10000000 if $self->masked;
        $string .= pack 'C', $payload_len;
    }
    elsif ($payload_len <= 0xffff) {
        $string .= pack 'C', 126 + ($self->masked ? 128 : 0);
        $string .= pack 'n', $payload_len;
    }
    else {
        $string .= pack 'C', 127 + ($self->masked ? 128 : 0);

        # Shifting by an amount >= to the system wordsize is undefined
        $string .= pack 'N', $Config{ivsize} <= 4 ? 0 : $payload_len >> 32;
        $string .= pack 'N', ($payload_len & 0xffffffff);
    }

    if ($self->masked) {

        # Not sure if perl provides good randomness
        my $mask = $self->{mask} || rand(2**32);

        $mask = pack 'N', $mask;

        $string .= $mask;
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
