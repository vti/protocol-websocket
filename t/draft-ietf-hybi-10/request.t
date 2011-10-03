#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 48;

use IO::Handle;

use_ok 'Protocol::WebSocket::Request';

my $req;
my $message;

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
ok $req->parse("Sec-WebSocket-Origin: http://example.com\x0d\x0a");
ok $req->parse("Sec-WebSocket-Protocol: chat, superchat\x0d\x0a");
ok $req->parse("Sec-WebSocket-Version: 8\x0d\x0a\x0d\x0a");
is $req->state => 'done';
is $req->key   => 'dGhlIHNhbXBsZSBub25jZQ==';

is $req->version       => 'draft-ietf-hybi-10';
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
ok $req->parse("Sec-WebSocket-Version: 8\x0d\x0a\x0d\x0a");
is $req->state         => 'done';
is $req->key           => 'dGhlIHNhbXBsZSBub25jZQ==';
is $req->version       => 'draft-ietf-hybi-10';
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
  . "Sec-WebSocket-Origin: http://example.com\x0d\x0a"
  . "Sec-WebSocket-Protocol: chat, superchat\x0d\x0a"
  . "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\x0d\x0a"
  . "Sec-WebSocket-Version: 8\x0d\x0a"
  . "\x0d\x0a";

open my $fh, '<', 't/empty' or die $!;
my $io = IO::Handle->new;
$io->fdopen(fileno($fh), "r");
$req = Protocol::WebSocket::Request->new_from_psgi(
    {   SCRIPT_NAME                 => '',
        PATH_INFO                   => '/chat',
        QUERY_STRING                => 'foo=bar',
        HTTP_UPGRADE                => 'websocket',
        HTTP_CONNECTION             => 'Upgrade',
        HTTP_HOST                   => 'server.example.com',
        HTTP_SEC_WEBSOCKET_ORIGIN   => 'http://example.com',
        HTTP_SEC_WEBSOCKET_PROTOCOL => 'chat, superchat',
        HTTP_SEC_WEBSOCKET_KEY      => 'dGhlIHNhbXBsZSBub25jZQ==',
        HTTP_SEC_WEBSOCKET_VERSION  => 8
    }
);
$req->parse($io);
is $req->resource_name => '/chat?foo=bar';
is $req->subprotocol   => 'chat, superchat';
is $req->upgrade       => 'websocket';
is $req->connection    => 'Upgrade';
is $req->host          => 'server.example.com';
is $req->origin        => 'http://example.com';
is $req->key           => 'dGhlIHNhbXBsZSBub25jZQ==';
ok $req->is_done;
is $req->version => 'draft-ietf-hybi-10';
