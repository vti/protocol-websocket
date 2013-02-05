#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 11;

use IO::Handle;

use_ok 'Protocol::WebSocket::Request';

my $req;

$req = Protocol::WebSocket::Request->new;

open my $fh, '<', \'' or die $!;
my $io = IO::Handle->new;
$io->fdopen(fileno($fh), "r");
$req = Protocol::WebSocket::Request->new_from_psgi(
    {   SCRIPT_NAME                 => '',
        PATH_INFO                   => '/chat',
        QUERY_STRING                => 'foo=bar',
        HTTP_UPGRADE                => 'websocket',
        HTTP_CONNECTION             => 'Upgrade',
        HTTP_HOST                   => 'server.example.com',
        HTTP_COOKIE                 => 'foo=bar',
        HTTP_SEC_WEBSOCKET_ORIGIN   => 'http://example.com',
        HTTP_SEC_WEBSOCKET_PROTOCOL => 'chat, superchat',
        HTTP_SEC_WEBSOCKET_KEY      => 'dGhlIHNhbXBsZSBub25jZQ==',
        HTTP_SEC_WEBSOCKET_VERSION  => 13
    }
);
$req->parse($io);
is $req->resource_name      => '/chat?foo=bar';
is $req->subprotocol        => 'chat, superchat';
is $req->upgrade            => 'websocket';
is $req->connection         => 'Upgrade';
is $req->host               => 'server.example.com';
is $req->cookies->to_string => 'foo=bar';
is $req->origin             => 'http://example.com';
is $req->key                => 'dGhlIHNhbXBsZSBub25jZQ==';
ok $req->is_done;
is $req->version => 'draft-ietf-hybi-17';
