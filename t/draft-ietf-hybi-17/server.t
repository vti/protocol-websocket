#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 15;

use_ok 'Protocol::WebSocket::Handshake::Server';

my $h = Protocol::WebSocket::Handshake::Server->new;

ok !$h->is_done;
ok $h->parse;
ok $h->parse('');

ok $h->parse("GET /demo HTTP/1.1\x0d\x0a");
ok $h->parse("Upgrade: websocket\x0d\x0a");
ok $h->parse("Connection: Upgrade\x0d\x0a");
ok $h->parse("Host: example.com\x0d\x0a");
ok $h->parse("Origin: http://example.com\x0d\x0a");
ok $h->parse("Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\x0d\x0a");
ok $h->parse("Sec-WebSocket-Version: 13\x0d\x0a");
ok $h->parse("\x0d\x0a");
ok !$h->error;
ok $h->is_done;

is $h->to_string => "HTTP/1.1 101 WebSocket Protocol Handshake\x0d\x0a"
  . "Upgrade: WebSocket\x0d\x0a"
  . "Connection: Upgrade\x0d\x0a"
  . "Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\x0d\x0a"
  . "\x0d\x0a";
