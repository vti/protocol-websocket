#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 117;

use_ok 'Protocol::WebSocket::Request';

my $req = Protocol::WebSocket::Request->new;
my $message;

is $req->state => 'request_line';
ok !$req->is_done;
ok $req->parse;
ok $req->parse('');
ok $req->parse("GET /demo HTTP/1.1\x0d\x0a");
is $req->state => 'fields';

ok $req->parse("Upgrade: WebSocket\x0d\x0a");
is $req->state => 'fields';
ok $req->parse("Connection: Upgrade\x0d\x0a");
is $req->state => 'fields';
ok $req->parse("Host: example.com\x0d\x0a");
is $req->state => 'fields';
ok $req->parse("Origin: http://example.com\x0d\x0a");
is $req->state => 'fields';
ok $req->parse(
    "Sec-WebSocket-Key1: 18x 6]8vM;54 *(5:  {   U1]8  z [  8\x0d\x0a");
ok $req->parse(
    "Sec-WebSocket-Key2: 1_ tx7X d  <  nw  334J702) 7]o}` 0\x0d\x0a");
is $req->state => 'fields';
ok $req->parse("\x0d\x0aTm[K T2u");
is $req->state     => 'done';
is $req->number1   => '155712099';
is $req->number2   => '173347027';
is $req->challenge => 'Tm[K T2u';

is $req->version       => 76;
is $req->resource_name => '/demo';
is $req->host          => 'example.com';
is $req->origin        => 'http://example.com';
is $req->checksum      => 'fQJ,fN/4F4!~K~MH';

$req = Protocol::WebSocket::Request->new;
is $req->state => 'request_line';
ok !$req->is_done;
ok $req->parse;
ok $req->parse('');
ok $req->parse("GET /demo HTTP/1.1\x0d\x0a");
is $req->state => 'fields';

ok $req->parse("Upgrade: WebSocket\x0d\x0a");
is $req->state => 'fields';
ok $req->parse("Connection: Upgrade\x0d\x0a");
is $req->state => 'fields';
ok $req->parse("Host: example.com\x0d\x0a");
is $req->state => 'fields';
ok $req->parse("Origin: http://example.com\x0d\x0a");
is $req->state => 'fields';
ok $req->parse("\x0d\x0a");
is $req->state => 'done';

is $req->version       => 75;
is $req->resource_name => '/demo';
is $req->host          => 'example.com';
is $req->origin        => 'http://example.com';

$req = Protocol::WebSocket::Request->new;
ok $req->parse("GET /demo HTTP/1.1\x0d\x0a");
ok $req->parse("Upgrade: WebSocket\x0d\x0a");
ok $req->parse("Connection: Upgrade\x0d\x0a");
ok $req->parse("Host: example.com:3000\x0d\x0a");
ok $req->parse("Origin: null\x0d\x0a");
ok $req->parse("\x0d\x0a");
is $req->version => 75;
is $req->state   => 'done';

$req = Protocol::WebSocket::Request->new;
$message =
    "GET /demo HTTP/1.1\x0d\x0a"
  . "Upgrade: WebSocket\x0d\x0a"
  . "Connection: Upgrade\x0d\x0a";
ok $req->parse($message);
is $message => '';
$message =
  "Host: example.com:3000\x0d\x0a" . "Origin: null\x0d\x0a" . "\x0d\x0a";
ok $req->parse($message);
is $message      => '';
is $req->version => 75;
ok $req->is_done;

$req = Protocol::WebSocket::Request->new;
ok $req->parse("GET /demo HTTP/1.1\x0d\x0a");
ok $req->parse("Upgrade: WebSocket\x0d\x0a");
ok $req->parse("Connection: Upgrade\x0d\x0a");
ok $req->parse("Host: example.com\x0d\x0a");
ok $req->parse("Origin: null\x0d\x0a");
ok $req->parse("Cookie: \$Version=1; foo=bar; \$Path=/\x0d\x0a");
ok $req->parse("\x0d\x0a");
is $req->state => 'done';

is $req->cookies->[0]->version => 1;
is $req->cookies->[0]->name    => 'foo';
is $req->cookies->[0]->value   => 'bar';

$req = Protocol::WebSocket::Request->new;
is $req->state => 'request_line';
ok !$req->is_done;
ok not defined $req->parse("foo\x0d\x0a");
ok $req->is_state('error');

$req = Protocol::WebSocket::Request->new;
ok $req->parse("GET /demo HTTP/1.1\x0d\x0a");
ok $req->parse("Upgrade: WebSocket\x0d\x0a");
ok $req->parse("Connection: Upgrade\x0d\x0a");
ok $req->parse("Origin: http://example.com\x0d\x0a");
ok not defined $req->parse("\x0d\x0a");
is $req->state => 'error';

$req = Protocol::WebSocket::Request->new;
ok not defined $req->parse('x' x (1024 * 10));
is $req->state => 'error';

$req = Protocol::WebSocket::Request->new;
ok $req->parse("GET /demo HTTP/1.1\x0d\x0a");
ok $req->parse("Upgrade: Foo\x0d\x0a");
ok $req->parse("Connection: Upgrade\x0d\x0a");
ok $req->parse("Host: example.com\x0d\x0a");
ok $req->parse("Origin: http://example.com\x0d\x0a");
ok not defined $req->parse("\x0d\x0a");
is $req->state => 'error';

$req = Protocol::WebSocket::Request->new;
ok $req->parse("GET /demo HTTP/1.1\x0d\x0a");
ok $req->parse("Upgrade: WebSocket\x0d\x0a");
ok $req->parse("Connection: Bar\x0d\x0a");
ok $req->parse("Host: example.com\x0d\x0a");
ok $req->parse("Origin: http://example.com\x0d\x0a");
ok not defined $req->parse("\x0d\x0a");
is $req->state => 'error';

$req = Protocol::WebSocket::Request->new;
ok $req->parse("GET /demo HTTP/1.1\x0d\x0a");
ok $req->parse("Upgrade: WebSocket\x0d\x0a");
ok $req->parse("Connection: Upgrade\x0d\x0a");
ok $req->parse("Host: example.com\x0d\x0a");
ok $req->parse("Origin: http://example.com\x0d\x0a");
ok not defined $req->parse("\x0d\x0afoo");
is $req->state => 'error';

$req = Protocol::WebSocket::Request->new(
    version       => 75,
    host          => 'example.com',
    resource_name => '/demo'
);
is $req->to_string => "GET /demo HTTP/1.1\x0d\x0a"
  . "Upgrade: WebSocket\x0d\x0a"
  . "Connection: Upgrade\x0d\x0a"
  . "Host: example.com\x0d\x0a"
  . "Origin: http://example.com\x0d\x0a"
  . "\x0d\x0a";

$req = Protocol::WebSocket::Request->new(
    version       => 75,
    host          => 'example.com',
    resource_name => '/demo'
);
is $req->to_string => "GET /demo HTTP/1.1\x0d\x0a"
  . "Upgrade: WebSocket\x0d\x0a"
  . "Connection: Upgrade\x0d\x0a"
  . "Host: example.com\x0d\x0a"
  . "Origin: http://example.com\x0d\x0a"
  . "\x0d\x0a";

$req = Protocol::WebSocket::Request->new(
    host          => 'example.com',
    resource_name => '/demo',
    key1          => '18x 6]8vM;54 *(5:  {   U1]8  z [  8',
    key2          => '1_ tx7X d  <  nw  334J702) 7]o}` 0',
    challenge     => 'Tm[K T2u'
);
is $req->to_string => "GET /demo HTTP/1.1\x0d\x0a"
  . "Upgrade: WebSocket\x0d\x0a"
  . "Connection: Upgrade\x0d\x0a"
  . "Host: example.com\x0d\x0a"
  . "Origin: http://example.com\x0d\x0a"
  . "Sec-WebSocket-Key1: 18x 6]8vM;54 *(5:  {   U1]8  z [  8\x0d\x0a"
  . "Sec-WebSocket-Key2: 1_ tx7X d  <  nw  334J702) 7]o}` 0\x0d\x0a"
  . "Content-Length: 8\x0d\x0a"
  . "\x0d\x0a"
  . "Tm[K T2u";
is $req->checksum => "fQJ,fN/4F4!~K~MH";

$req = Protocol::WebSocket::Request->new(
    host          => 'example.com',
    resource_name => '/demo',
    key1          => '55 997',
    key2          => '3  3  64  98',
    challenge     => "\x00\x09\x68\x32\x00\x78\xc7\x10"
);
is $req->checksum =>
  "\xc4\x15\xc2\xc8\x29\x5c\x94\x8a\x95\xb9\x4d\xec\x5b\x1d\x33\xce";

$req = Protocol::WebSocket::Request->new(
    host          => 'example.com',
    resource_name => '/demo'
);
$req->to_string;
ok $req->number1;
ok $req->key1;
ok $req->number2;
ok $req->key2;
is length($req->challenge) => 8;
is length($req->checksum)  => 16;
