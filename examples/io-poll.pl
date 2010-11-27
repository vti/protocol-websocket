#!/usr/bin/env perl

use strict;
use warnings;

use IO::Socket::INET;
use IO::Poll qw/POLLIN/;

use Protocol::WebSocket::Handshake::Server;
use Protocol::WebSocket::Frame;

my $poll = IO::Poll->new;

my $socket = IO::Socket::INET->new(
    Blocking  => 0,
    LocalAddr => 'localhost',
    LocalPort => 3000,
    Proto     => 'tcp',
    Type      => SOCK_STREAM,
    Listen    => 1
);

$socket->blocking(0);

$socket->listen;

my $client;

while (1) {
    if ($client = $socket->accept) {
        $poll->mask($client => POLLIN);
        last;
    }
}

my $hs    = Protocol::WebSocket::Handshake::Server->new;
my $frame = Protocol::WebSocket::Frame->new;

LOOP: while (1) {
    $poll->poll(0.1);

    foreach my $reader ($poll->handles(POLLIN)) {
        my $rs = $client->sysread(my $chunk, 1024);
        last LOOP unless $rs;

        if (!$hs->is_done) {
            $hs->parse($chunk);

            if ($hs->is_done) {
                $client->syswrite($hs->to_string);
            }

            next;
        }

        $frame->append($chunk);

        while (my $message = $frame->next) {
            $client->syswrite($frame->new($message)->to_string);
        }
    }
}
