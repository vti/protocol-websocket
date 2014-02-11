#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

use_ok 'Protocol::WebSocket::Client';

subtest 'write handshake on connect' => sub {
    my $client = Protocol::WebSocket::Client->new(url => 'ws://localhost:8080');

    my $written = '';
    $client->on(write => sub { $written .= $_[1] });

    $client->connect;

    like $written, qr/Upgrade: WebSocket/;
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

done_testing;
