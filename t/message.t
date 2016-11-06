#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 10;

use IO::Handle;

use_ok 'Protocol::WebSocket::Message';

my $m;

$m = Protocol::WebSocket::Message->new;
ok $m->parse("HTTP/1.1 101 WebSocket Protocol Handshake\x0d\x0a");
ok $m->parse("Upgrade: WebSocket\x0d\x0a");
ok $m->parse("Connection: Upgrade\x0d\x0a");
ok $m->parse("Sec-WebSocket-Origin: file://\x0d\x0a");
ok $m->parse("Sec-WebSocket-Location: ws://example.com/demo\x0d\x0a");
ok $m->parse("\x0d\x0a0st\x0d\x0al&q-2ZU^weu");
ok $m->is_done;

open my $fh, '<', 't/message' or die $!;
my $io = IO::Handle->new;
$io->fdopen(fileno($fh), "r");

$m = Protocol::WebSocket::Message->new;
$m->parse($io);
ok $m->is_done;

subtest 'multiple same named fields' => sub {
    $m = Protocol::WebSocket::Message->new;
    ok $m->parse("HTTP/1.1 101 WebSocket Protocol Handshake\x0d\x0a");
    ok $m->parse("Upgrade: WebSocket\x0d\x0a");
    ok $m->parse("Connection: Upgrade\x0d\x0a");
    ok $m->parse("Sec-WebSocket-Origin: file://\x0d\x0a");
    ok $m->parse("Sec-WebSocket-Location: ws://example.com/demo\x0d\x0a");
    ok $m->parse("X-Foo: bar\x0d\x0a");
    ok $m->parse("X-Foo: baz\x0d\x0a");
    ok $m->parse("\x0d\x0a0st\x0d\x0al&q-2ZU^weu");
    ok $m->is_done;
    is $m->fields->{'connection'}, 'Upgrade';
    is $m->fields->{'x-foo'}, 'bar,baz';
};
