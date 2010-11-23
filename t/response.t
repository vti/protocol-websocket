#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 17;

use_ok 'Protocol::WebSocket::Response';

my $res;

$res = Protocol::WebSocket::Response->new;
$res->version(75);
$res->host('example.com');

is $res->to_string => "HTTP/1.1 101 WebSocket Protocol Handshake\x0d\x0a"
  . "Upgrade: WebSocket\x0d\x0a"
  . "Connection: Upgrade\x0d\x0a"
  . "\x0d\x0a";

$res = Protocol::WebSocket::Response->new;
$res->version(75);
$res->host('example.com');
$res->resource_name('/demo');
$res->origin('file://');
$res->cookie(name => 'foo', value => 'bar', path => '/');

is $res->to_string => "HTTP/1.1 101 WebSocket Protocol Handshake\x0d\x0a"
  . "Upgrade: WebSocket\x0d\x0a"
  . "Connection: Upgrade\x0d\x0a"
  . "Set-Cookie: foo=bar; Path=/; Version=1\x0d\x0a"
  . "\x0d\x0a";

$res = Protocol::WebSocket::Response->new;
ok $res->parse("HTTP/1.1 101 WebSocket Protocol Handshake\x0d\x0a");
ok $res->parse("Upgrade: WebSocket\x0d\x0a");
ok $res->parse("Connection: Upgrade\x0d\x0a");
ok $res->parse("Sec-WebSocket-Origin: file://\x0d\x0a");
ok $res->parse("Sec-WebSocket-Location: ws://example.com/demo\x0d\x0a");
ok $res->parse("\x0d\x0a");
ok $res->parse("0st3Rl&q-2ZU^weu");
ok $res->is_done;

is $res->checksum => '0st3Rl&q-2ZU^weu';
ok !$res->secure;
is $res->host          => 'example.com';
is $res->resource_name => '/demo';
is $res->origin        => 'file://';

$res = Protocol::WebSocket::Response->new(
    host          => 'example.com',
    resource_name => '/demo',
    origin        => 'file://',
    number1       => 777_007_543,
    number2       => 114_997_259,
    challenge     => "\x47\x30\x22\x2D\x5A\x3F\x47\x58"
);
is $res->to_string => "HTTP/1.1 101 WebSocket Protocol Handshake\x0d\x0a"
  . "Upgrade: WebSocket\x0d\x0a"
  . "Connection: Upgrade\x0d\x0a"
  . "Sec-WebSocket-Origin: file://\x0d\x0a"
  . "Sec-WebSocket-Location: ws://example.com/demo\x0d\x0a"
  . "\x0d\x0a"
  . "0st3Rl&q-2ZU^weu";
