package Protocol::WebSocket::Client;

use strict;
use warnings;

require Carp;
use Protocol::WebSocket::URL;
use Protocol::WebSocket::Handshake::Client;
use Protocol::WebSocket::Frame;

sub new {
    my $class = shift;
    $class = ref $class if ref $class;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    Carp::croak('url is required') unless $params{url};
    $self->{url} = Protocol::WebSocket::URL->new->parse($params{url})
      or Carp::croak("Can't parse url");

    $self->{version} = $params{version};

    # User callbacks.  Only write and read are mandatory.
    $self->{on_write} = $params{on_write};
    $self->{on_read} = $params{on_read};

    # Additional callbacks for other WS events
    $self->{on_connect} = $params{on_connect};
    $self->{on_eof}   = $params{on_eof};
    $self->{on_error} = $params{on_error};
    $self->{on_pong} = $params{on_pong};

    # register auto-pong by default
    if (exists $params{on_ping}) {
        $self->{on_ping} = $params{on_ping};
    } else {
        $self->{on_ping} = \&pong;
    }

    $self->{hs} =
      Protocol::WebSocket::Handshake::Client->new(url => $self->{url});

    # optional parameters for the frame buffer
    my %frame_buffer_params;
    $frame_buffer_params{max_fragments_amount} = $params{max_fragments_amount} if exists $params{max_fragments_amount};
    $frame_buffer_params{max_payload_size} = $params{max_payload_size} if exists $params{max_payload_size};

    $self->{frame_buffer} = $self->_build_frame(%frame_buffer_params);

    # Flag indicating current state
    #  0 = not connected yet,
    #  1 = ready,
    # -1 = connection closed.
    $self->{state} = 0;

    return $self;
}

# function stubs around member vars
sub url     { shift->{url} }
sub version { shift->{version} }
sub is_ready { shift->{state} > 0 }

# register callbacks after construction
sub on {
    my $self = shift;
    my (%handlers) = @_;

    foreach my $event (keys %handlers)
    {
        $self->{"on_$event"} = $handlers{$event};
    }

    return $self;
}

sub read {
    my $self = shift;
    my ($buffer) = @_;

    my $hs           = $self->{hs};
    my $frame_buffer = $self->{frame_buffer};

    # handshake is always the beginning of the WS process
    unless ($hs->is_done) {
        if (!$hs->parse($buffer)) {
            $self->{on_error}->($self, $hs->error);
            return $self;
        }

        if ($hs->is_done) {
            $self->{state} = 1;
            $self->{on_connect}->($self) if $self->{on_connect};
        }
    }

    # handshake has been completed, this is user-mode now
    if ($hs->is_done) {
        $frame_buffer->append($buffer);

        while (defined (my $bytes = $frame_buffer->next)) {
            if ($frame_buffer->is_close) {
                # Remote WebSocket close (TCP socket may stay open for a bit)
                $self->disconnect if ($self->is_ready);
                # TODO: see message in disconnect() about error code / reason
                $self->{on_eof}->($self) if $self->{on_eof};
            } elsif ($frame_buffer->is_pong) {
                # Server responded to our ping.
                $self->{on_pong}->($self, $bytes) if $self->{on_pong};
            } elsif ($frame_buffer->is_ping) {
                # Server sent ping request.
                $self->{on_ping}->($self, $bytes) if $self->{on_ping};
            } else {
                $self->{on_read}->($self, $bytes);
            }
        }
    }

    return $self;
}

# Write arbitrary message.
#  Takes either a Protocol::WebSocket::Frame object, or
#  if given a scalar, builds a standard frame around it.
# In either case, calls user on_write function.
sub write {
    my $self = shift;
    my ($buffer) = @_;

    if ($self->is_ready) {
        my $frame =
          ref $buffer
          ? $buffer
          : $self->_build_frame(masked => 1, buffer => $buffer);
        $self->{on_write}->($self, $frame->to_bytes);
    } else {
        warn "Protocol::WebSocket::Client: write() on " . ($self->{state} ? 'closed' : 'unconnected') . " WebSocket.";
    }

    return $self;
}

# Write preformatted messages
# "connect" (initial handshake)
sub connect {
    my $self = shift;

    if ($self->{state} == 0) {
        my $hs = $self->{hs};

        $self->{on_write}->($self, $hs->to_string);
    } else {
        warn "Protocol::WebSocket::Client: connect() on " . ($self->{state} > 0 ? 'already-connected' : 'closed') . " WebSocket.";
    }

    return $self;
}

# "disconnect" (close frame)
#  also sets state to -1 when called
sub disconnect {
    my $self = shift;

    # TODO: Spec states 'close' messages may contain a uint16 error code, and a utf-8 reason.
    #  Clients are supposed to echo back the error code when receiving close from server.
    # For now, we just send an empty message.
    $self->write( $self->_build_frame(type => 'close', masked => 1) );

    $self->{state} = -1;

    return $self;
}

# "ping" (keep-alive, client to server)
sub ping {
    my $self = shift;
    my ($buffer) = @_;

    $self->write( $self->_build_frame(type => 'ping', masked => 1, buffer => $buffer) );

    return $self;
}

# "pong" (keep-alive, server to client)
sub pong {
    my $self = shift;
    my ($buffer) = @_;

    $self->write( $self->_build_frame(type => 'pong', masked => 1, buffer => $buffer) );

    return $self;
}

# Class-specific internal functions
sub _build_frame {
    my $self = shift;

    return Protocol::WebSocket::Frame->new(version => $self->{version}, @_);
}

1;
__END__

=head1 NAME

Protocol::WebSocket::Client - WebSocket client

=head1 SYNOPSIS

    my $sock = ...get non-blocking socket...;

    my $client = Protocol::WebSocket->new(url => 'ws://localhost:3000');
    $client->on(
        write => sub {
            my $client = shift;
            my ($buf) = @_;

            syswrite $sock, $buf;
        }
    );
    $client->on(
        read => sub {
            my $client = shift;
            my ($buf) = @_;

            ...do smth with read data...
        }
    );

    # Sends a correct handshake header
    $client->connect;

    # Register on connect handler
    $client->on(
        connect => sub {
            $client->write('hi there');
        }
    );

    # Parses incoming data and on every frame calls on_read
    $client->read(...data from socket...);

    # Sends correct close header
    $client->disconnect;

=head1 DESCRIPTION

L<Protocol::WebSocket::Client> is a convenient class for writing a WebSocket
client.

=cut
