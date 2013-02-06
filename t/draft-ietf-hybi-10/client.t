#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 8;

use_ok 'Protocol::WebSocket::Handshake::Client';

my $h = Protocol::WebSocket::Handshake::Client->new(version => 'draft-ietf-hybi-10');
$h->url('ws://example.com/demo');

# Mocking
$h->req->key("dGhlIHNhbXBsZSBub25jZQ==");
$h->req->cookies('foo=bar; alice=bob');

is $h->to_string => "GET /demo HTTP/1.1\x0d\x0a"
  . "Upgrade: WebSocket\x0d\x0a"
  . "Connection: Upgrade\x0d\x0a"
  . "Host: example.com\x0d\x0a"
  . "Cookie: foo=bar; alice=bob\x0d\x0a"
  . "Sec-WebSocket-Origin: http://example.com\x0d\x0a"
  . "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\x0d\x0a"
  . "Sec-WebSocket-Version: 8\x0d\x0a"
  . "\x0d\x0a";

ok !$h->is_done;
ok $h->parse;
ok $h->parse('');

ok $h->parse("HTTP/1.1 101 Switching Protocols\x0d\x0a"
      . "Upgrade: websocket\x0d\x0a"
      . "Connection: Upgrade\x0d\x0a"
      . "Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\x0d\x0a"
      . "\x0d\x0a");
ok !$h->error;
ok $h->is_done;
