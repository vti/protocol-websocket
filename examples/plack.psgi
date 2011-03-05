#!/usr/bin/env perl

use strict;
use warnings;

use lib 'lib';

use AnyEvent::Handle;
use Protocol::WebSocket::Handshake::Server;
use Protocol::WebSocket::Frame;

my $handles = {};

my $psgi_app = sub {
    my $env = shift;

    if (   !$env->{HTTP_CONNECTION}
        || !$env->{HTTP_UPGRADE}
        || $env->{HTTP_CONNECTION} ne 'Upgrade'
        || $env->{HTTP_UPGRADE} ne 'WebSocket' )
    {
        return [400, [], []];
    }

    my $fh = $env->{'psgix.io'};
    return [501, [], []] unless $fh;

    my $hs = Protocol::WebSocket::Handshake::Server->new_from_psgi($env);
    $hs->parse($fh);

    if ($hs->error) {
        return [400, [], [$hs->error]];
    }

    return sub {
        my $respond = shift;

        my $fh = $env->{'psgix.io'} or return $respond->([501, [], []]);

        my $h = AnyEvent::Handle->new(fh => $fh);
        my $frame = Protocol::WebSocket::Frame->new;

        $handles->{fileno($fh)} = {handle => $h, frame => $frame};

        $h->push_write($hs->to_string);

        $h->on_read(
            sub {
                $frame->append($_[0]->rbuf);

                while (my $message = $frame->next) {
                    $h->push_write(Protocol::WebSocket::Frame->new($message)->to_string);
                }
            }
        );
    };
};

$psgi_app;
