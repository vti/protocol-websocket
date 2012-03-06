#!/usr/bin/env perl

use strict;
use warnings;

use lib 'lib';

use AnyEvent::Handle;
use Protocol::WebSocket::Handshake::Server;
use Protocol::WebSocket::Frame;

my $psgi_app = sub {
    my $env = shift;

    my $fh = $env->{'psgix.io'} or return [500, [], []];

    my $hs = Protocol::WebSocket::Handshake::Server->new_from_psgi($env);
    $hs->parse($fh) or return [400, [], [$hs->error]];

    return sub {
        my $respond = shift;

        my $h = AnyEvent::Handle->new(fh => $fh);
        my $frame = Protocol::WebSocket::Frame->new;

        $h->push_write($hs->to_string);

        $h->on_read(
            sub {
                $frame->append($_[0]->rbuf);

                while (my $message = $frame->next) {
                    $h->push_write(Protocol::WebSocket::Frame->new($message)->to_bytes);
                }
            }
        );
    };
};

$psgi_app;
