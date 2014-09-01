#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use IO::Handle;
use Protocol::WebSocket::Handshake::Server;

use_ok 'Protocol::WebSocket::Client';

subtest 'write handshake on connect' => sub {
    my $client = Protocol::WebSocket::Client->new(url => 'ws://localhost:8080');

    my $written = '';
    $client->on(write => sub { $written .= $_[1] });

    $client->connect;

    like $written, qr/Upgrade: WebSocket/;
};

subtest 'call on_connect on connect' => sub {
    my $client = Protocol::WebSocket::Client->new(url => 'ws://localhost:8080');

    $client->on(write => sub { });

    my $connected;
    $client->on(
        connect => sub {
            $connected++;
        }
    );

    $client->connect;

    _recv_server_handshake($client);

    ok $connected;
};

subtest 'call on_read on new data' => sub {
    my $client = Protocol::WebSocket::Client->new(url => 'ws://localhost:8080');

    my $read = '';
    $client->on(write => sub { });
    $client->on(read => sub { $read .= $_[1] });

    $client->connect;

    _recv_server_handshake($client);

    my $frame = Protocol::WebSocket::Frame->new(
        version => $client->version,
        buffer  => 'hello'
    );
    $client->read($frame->to_bytes);

    is $read, 'hello';
};

subtest 'write close frame on disconnect' => sub {
    my $client = Protocol::WebSocket::Client->new(url => 'ws://localhost:8080');

    my $written = '';
    $client->on(write => sub { $written .= $_[1] });

    $client->disconnect;

    is $written, "\x88\x00";
};

subtest 'call on_write on write' => sub {
    my $client = Protocol::WebSocket::Client->new(url => 'ws://localhost:8080');

    my $written = '';
    $client->on(write => sub { $written .= $_[1] });

    $client->write('foobar');

    isnt $written, '';
};

sub _recv_server_handshake {
    my ($client) = @_;

    open my $fh, '<', \'' or die $!;
    my $io = IO::Handle->new;
    $io->fdopen(fileno($fh), "r");
    my $hs = Protocol::WebSocket::Handshake::Server->new_from_psgi(
        SCRIPT_NAME                => '',
        PATH_INFO                  => '/chat',
        HTTP_UPGRADE               => 'websocket',
        HTTP_CONNECTION            => 'Upgrade',
        HTTP_HOST                  => 'server.example.com',
        HTTP_SEC_WEBSOCKET_ORIGIN  => 'http://example.com',
        HTTP_SEC_WEBSOCKET_KEY     => 'dGhlIHNhbXBsZSBub25jZQ==',
        HTTP_SEC_WEBSOCKET_VERSION => 13,
    );
    $hs->parse($io);

    $client->read($hs->to_string);
}

done_testing;
