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

    $self->{url} = Protocol::WebSocket::URL->new->parse($params{url})
      or Carp::croak("Can't parse url");

    $self->{version}  = $params{version};
    $self->{on_write} = $params{on_write};
    $self->{on_frame} = $params{on_frame};
    $self->{on_eof}   = $params{on_eof};
    $self->{on_error} = $params{on_error};

    $self->{hs} =
      Protocol::WebSocket::Handshake::Client->new(url => $self->{url});
    $self->{frame_buffer} = $self->_build_frame;

    return $self;
}

sub url { shift->{url} }

sub on {
    my $self = shift;
    my ($event, $cb) = @_;

    $self->{"on_$event"} = $cb;

    return $self;
}

sub read {
    my $self = shift;
    my ($buffer) = @_;

    my $hs           = $self->{hs};
    my $frame_buffer = $self->{frame_buffer};

    unless ($hs->is_done) {
        if (!$hs->parse($buffer)) {
            $self->{on_error}->($self, $hs->error);
            return $self;
        }
    }

    if ($hs->is_done) {
        $frame_buffer->append($buffer);

        while (my $bytes = $frame_buffer->next) {
            $self->{on_read}->($self, $bytes);

            #$self->{on_frame}->($self, $bytes);
        }
    }

    return $self;
}

sub write {
    my $self = shift;
    my ($buffer) = @_;

    my $frame =
      ref $buffer
      ? $buffer
      : $self->_build_frame(masked => 1, buffer => $buffer);
    $self->{on_write}->($self, $frame->to_bytes);

    return $self;
}

sub connect {
    my $self = shift;

    my $hs = $self->{hs};

    $self->{on_write}->($self, $hs->to_string);

    return $self;
}

sub disconnect {
    my $self = shift;

    return $self;
}

sub _build_frame {
    my $self = shift;

    return Protocol::WebSocket::Frame->new(version => $self->{version}, @_);
}

1;
