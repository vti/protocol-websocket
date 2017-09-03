#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 6;

use_ok 'Protocol::WebSocket::Response';

my $res;

$res = Protocol::WebSocket::Response->new;
$res->parse("foo\x0d\x0a");
ok $res->is_state('error');
is $res->error => 'Wrong response line';

local $Protocol::WebSocket::Message::MAX_MESSAGE_SIZE = 1024;

$res = Protocol::WebSocket::Response->new;
ok not defined $res->parse('x' x (1024 * 10));
ok $res->is_state('error');
is $res->error => 'Message is too long';
