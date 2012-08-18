#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 54;

use_ok 'Protocol::WebSocket::Request';

my $req;

$req = Protocol::WebSocket::Request->new;

ok !$req->is_done;
ok $req->parse;
ok $req->parse('');
ok $req->parse("GET /chat HTTP/1.1\x0d\x0a");
is $req->state => 'fields';

ok $req->parse("Host: server.example.com\x0d\x0a");
is $req->state => 'fields';
ok $req->parse("Upgrade: websocket\x0d\x0a");
is $req->state => 'fields';
ok $req->parse("Connection: Upgrade\x0d\x0a");
is $req->state => 'fields';
ok $req->parse("Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\x0d\x0a");
ok $req->parse("Origin: http://example.com\x0d\x0a");
ok $req->parse("Sec-WebSocket-Protocol: chat, superchat\x0d\x0a");
ok $req->parse("Sec-WebSocket-Version: 13\x0d\x0a\x0d\x0a");
is $req->state => 'done';
is $req->key   => 'dGhlIHNhbXBsZSBub25jZQ==';

is $req->version       => 'draft-ietf-hybi-17';
is $req->subprotocol   => 'chat, superchat';
is $req->resource_name => '/chat';
is $req->host          => 'server.example.com';
is $req->origin        => 'http://example.com';

$req = Protocol::WebSocket::Request->new;

ok $req->parse("GET /chat HTTP/1.1\x0d\x0a");
ok $req->parse("Host: server.example.com\x0d\x0a");
ok $req->parse("Upgrade: websocket\x0d\x0a");
ok $req->parse("Connection:keep-alive, Upgrade\x0d\x0a");
ok $req->parse("Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\x0d\x0a");
ok $req->parse("Origin: http://example.com\x0d\x0a");
ok $req->parse("Sec-WebSocket-Protocol: chat, superchat\x0d\x0a");
ok $req->parse("Sec-WebSocket-Version: 13\x0d\x0a\x0d\x0a");
is $req->state         => 'done';
is $req->key           => 'dGhlIHNhbXBsZSBub25jZQ==';
is $req->version       => 'draft-ietf-hybi-17';
is $req->subprotocol   => 'chat, superchat';
is $req->resource_name => '/chat';
is $req->host          => 'server.example.com';
is $req->origin        => 'http://example.com';

$req = Protocol::WebSocket::Request->new;

ok $req->parse("GET /chat HTTP/1.1\x0d\x0a");
ok $req->parse("Host: server.example.com\x0d\x0a");
ok $req->parse("Upgrade: websocket\x0d\x0a");
ok $req->parse("Connection:keep-alive, Upgrade\x0d\x0a");
ok $req->parse("Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\x0d\x0a");
ok $req->parse("Sec-WebSocket-Origin: http://example.com\x0d\x0a");
ok $req->parse("Sec-WebSocket-Protocol: chat, superchat\x0d\x0a");
ok $req->parse("Sec-WebSocket-Version: 13\x0d\x0a\x0d\x0a");
is $req->state         => 'done';
is $req->key           => 'dGhlIHNhbXBsZSBub25jZQ==';
is $req->version       => 'draft-ietf-hybi-17';
is $req->subprotocol   => 'chat, superchat';
is $req->resource_name => '/chat';
is $req->host          => 'server.example.com';
is $req->origin        => 'http://example.com';

$req = Protocol::WebSocket::Request->new(
    host          => 'server.example.com',
    origin        => 'http://example.com',
    subprotocol   => 'chat, superchat',
    resource_name => '/chat',
    key           => 'dGhlIHNhbXBsZSBub25jZQ=='
);
is $req->to_string => "GET /chat HTTP/1.1\x0d\x0a"
  . "Upgrade: WebSocket\x0d\x0a"
  . "Connection: Upgrade\x0d\x0a"
  . "Host: server.example.com\x0d\x0a"
  . "Origin: http://example.com\x0d\x0a"
  . "Sec-WebSocket-Protocol: chat, superchat\x0d\x0a"
  . "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\x0d\x0a"
  . "Sec-WebSocket-Version: 13\x0d\x0a"
  . "\x0d\x0a";
