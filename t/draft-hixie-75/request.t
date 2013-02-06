#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 110;

use IO::Handle;

use_ok 'Protocol::WebSocket::Request';

my $req = Protocol::WebSocket::Request->new;
my $message;

$req = Protocol::WebSocket::Request->new;
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
ok $req->parse("Cookie: foo=bar;alice=bob\x0d\x0a");
is $req->state => 'fields';
ok $req->parse("Origin: http://example.com\x0d\x0a");
is $req->state => 'fields';
ok $req->parse("\x0d\x0a");
is $req->state => 'done';

is $req->version            => 'draft-hixie-75';
is $req->resource_name      => '/demo';
is $req->host               => 'example.com';
is $req->cookies->to_string => 'foo=bar; alice=bob';
is $req->origin             => 'http://example.com';

$req = Protocol::WebSocket::Request->new;
ok $req->parse("GET /demo HTTP/1.1\x0d\x0a");
ok $req->parse("Upgrade: WebSocket\x0d\x0a");
ok $req->parse("Connection: Upgrade\x0d\x0a");
ok $req->parse("Host: example.com:3000\x0d\x0a");
ok $req->parse("Origin: null\x0d\x0a");
ok $req->parse("\x0d\x0a");
is $req->version => 'draft-hixie-75';
is $req->state   => 'done';

$req = Protocol::WebSocket::Request->new;
ok $req->parse("GET /demo HTTP/1.1\x0d\x0a");
ok $req->parse("UPGRADE: WebSocket\x0d\x0a");
ok $req->parse("CONNECTION: Upgrade\x0d\x0a");
ok $req->parse("HOST: example.com:3000\x0d\x0a");
ok $req->parse("ORIGIN: null\x0d\x0a");
ok $req->parse("\x0d\x0a");
is $req->version => 'draft-hixie-75';
is $req->state   => 'done';

$req = Protocol::WebSocket::Request->new;
ok $req->parse("GET /demo HTTP/1.1\x0d\x0a");
ok $req->parse("Upgrade: WebSocket\x0d\x0a");
ok $req->parse("Connection: Upgrade\x0d\x0a");
ok $req->parse("Host: example.com:3000\x0d\x0a");
ok $req->parse("Origin: null\x0d\x0a");
ok $req->parse("WebSocket-Protocol: sample\x0d\x0a");
ok $req->parse("\x0d\x0a");
is $req->version     => 'draft-hixie-75';
is $req->state       => 'done';
is $req->subprotocol => 'sample';

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
is $req->version => 'draft-hixie-75';
ok $req->is_done;

$req = Protocol::WebSocket::Request->new;
ok $req->parse("GET /demo HTTP/1.1\x0d\x0a");
ok $req->parse("Upgrade: WebSocket\x0d\x0a");
ok $req->parse("Connection: Upgrade\x0d\x0a");
ok $req->parse("Host: example.com\x0d\x0a");
ok $req->parse("Origin: null\x0d\x0a");
ok $req->parse("Cookie: \$Version=1; foo=bar; \$Path=/\x0d\x0a");
ok $req->parse("\x0d\x0a");
ok $req->is_done;

is $req->cookies->pairs->[0][0] => '$Version';
is $req->cookies->pairs->[0][1] => '1';
is $req->cookies->pairs->[1][0] => 'foo';
is $req->cookies->pairs->[1][1] => 'bar';
is $req->cookies->pairs->[2][0] => '$Path';
is $req->cookies->pairs->[2][1] => '/';

$req = Protocol::WebSocket::Request->new;
$req->parse("GET /demo HTTP/1.1\x0d\x0a");
$req->parse("Upgrade: WebSocket\x0d\x0a");
$req->parse("Connection: Upgrade\x0d\x0a");
$req->parse("Host: example.com\x0d\x0a");
$req->parse("Origin: null\x0d\x0a");
$req->parse("X-Forwarded-Proto: https\x0d\x0a");
$req->parse("\x0d\x0a");
ok $req->is_done;
ok $req->secure;

$req = Protocol::WebSocket::Request->new;
ok $req->parse("GET /demo HTTP/1.1\x0d\x0a");
ok $req->parse("Upgrade: WebSocket\x0d\x0a");
ok $req->parse("Connection: Upgrade\x0d\x0a");
ok $req->parse("Host: example.com\x0d\x0a");
ok $req->parse("Origin: https://example.com\x0d\x0a");
ok $req->parse("\x0d\x0a");
ok $req->is_done;
ok $req->secure;

$req = Protocol::WebSocket::Request->new(
    version       => 'draft-hixie-75',
    host          => 'example.com',
    cookies       => Protocol::WebSocket::Cookie->new->parse('foo=bar; alice=bob'),
    resource_name => '/demo'
);
is $req->to_string => "GET /demo HTTP/1.1\x0d\x0a"
  . "Upgrade: WebSocket\x0d\x0a"
  . "Connection: Upgrade\x0d\x0a"
  . "Host: example.com\x0d\x0a"
  . "Cookie: foo=bar; alice=bob\x0d\x0a"
  . "Origin: http://example.com\x0d\x0a"
  . "\x0d\x0a";

$req = Protocol::WebSocket::Request->new(
    version       => 'draft-hixie-75',
    host          => 'example.com',
    subprotocol   => 'sample',
    resource_name => '/demo'
);
is $req->to_string => "GET /demo HTTP/1.1\x0d\x0a"
  . "Upgrade: WebSocket\x0d\x0a"
  . "Connection: Upgrade\x0d\x0a"
  . "Host: example.com\x0d\x0a"
  . "Origin: http://example.com\x0d\x0a"
  . "WebSocket-Protocol: sample\x0d\x0a"
  . "\x0d\x0a";

$req = Protocol::WebSocket::Request->new(
    version       => 'draft-hixie-75',
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
    secure        => 1,
    version       => 'draft-hixie-75',
    host          => 'example.com',
    resource_name => '/demo'
);
is $req->to_string => "GET /demo HTTP/1.1\x0d\x0a"
  . "Upgrade: WebSocket\x0d\x0a"
  . "Connection: Upgrade\x0d\x0a"
  . "Host: example.com\x0d\x0a"
  . "Origin: https://example.com\x0d\x0a"
  . "\x0d\x0a";

$req = Protocol::WebSocket::Request->new;
ok $req->parse("GET /demo HTTP/1.1\x0d\x0a");
ok $req->parse("Upgrade: WebSocket\x0d\x0a");
ok $req->parse("Connection: Bar\x0d\x0a");
ok $req->parse("Host: example.com\x0d\x0a");
ok $req->parse("Origin: http://example.com\x0d\x0a");
ok not defined $req->parse("\x0d\x0a");
ok $req->is_state('error');
is $req->error => 'Not a valid request';

$req = Protocol::WebSocket::Request->new;
ok $req->parse("GET /demo HTTP/1.1\x0d\x0a");
ok $req->parse("Upgrade: WebSocket\x0d\x0a");
ok $req->parse("Connection: Upgrade\x0d\x0a");
ok $req->parse("Host: example.com\x0d\x0a");
ok $req->parse("Origin: http://example.com\x0d\x0a");
ok not defined $req->parse("\x0d\x0afoo");
ok $req->is_state('error');
is $req->error => 'Leftovers';

eval { Protocol::WebSocket::Request->new_from_psgi() };
ok $@;

eval { Protocol::WebSocket::Request->new_from_psgi({}) };
ok $@;

open my $fh, '<', 't/empty' or die $!;
my $io = IO::Handle->new;
$io->fdopen(fileno($fh), "r");
$req = Protocol::WebSocket::Request->new_from_psgi(
    {   SCRIPT_NAME             => '',
        PATH_INFO               => '/demo',
        HTTP_UPGRADE            => 'WebSocket',
        HTTP_CONNECTION         => 'Upgrade',
        HTTP_HOST               => 'example.com:3000',
        HTTP_ORIGIN             => 'null',
        HTTP_WEBSOCKET_PROTOCOL => 'sample'
    }
);
$req->parse($io);
is $req->subprotocol   => 'sample';
is $req->resource_name => '/demo';
is $req->upgrade       => 'WebSocket';
is $req->connection    => 'Upgrade';
is $req->host          => 'example.com:3000';
is $req->origin        => 'null';
ok $req->is_done;
is $req->version => 'draft-hixie-75';

$req = Protocol::WebSocket::Request->new_from_psgi(
    {   SCRIPT_NAME             => '',
        PATH_INFO               => '/demo',
        HTTP_UPGRADE            => 'WebSocket',
        HTTP_CONNECTION         => 'Upgrade',
        HTTP_HOST               => 'example.com:3000',
        HTTP_ORIGIN             => 'null',
        HTTP_WEBSOCKET_PROTOCOL => 'sample',
        HTTP_X_FORWARDED_PROTO  => 'https'
    }
);
$req->parse($io);
ok $req->secure;
