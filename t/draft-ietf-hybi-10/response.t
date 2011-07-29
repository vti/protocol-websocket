#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 11;

use_ok 'Protocol::WebSocket::Response';

my $res;

$res = Protocol::WebSocket::Response->new;
ok $res->parse("HTTP/1.1 101 Switching Protocols\x0d\x0a");
ok $res->parse("Upgrade: websocket\x0d\x0a");
ok $res->parse("Connection: Upgrade\x0d\x0a");
ok $res->parse("Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\x0d\x0a");
ok $res->parse("Sec-WebSocket-Protocol: chat\x0d\x0a");
ok $res->parse("\x0d\x0a");
ok $res->is_done;
ok !$res->secure;
is $res->subprotocol => 'chat';

$res = Protocol::WebSocket::Response->new(
    key         => 'dGhlIHNhbXBsZSBub25jZQ==',
    subprotocol => 'chat'
);
is $res->to_string => "HTTP/1.1 101 WebSocket Protocol Handshake\x0d\x0a"
  . "Upgrade: WebSocket\x0d\x0a"
  . "Connection: Upgrade\x0d\x0a"
  . "Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\x0d\x0a"
  . "Sec-WebSocket-Protocol: chat\x0d\x0a"
  . "\x0d\x0a";
