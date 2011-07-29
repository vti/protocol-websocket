#!/usr/bin/env perl

use strict;
use warnings;

use utf8;

use Test::More tests => 23;

use Encode;

use_ok 'Protocol::WebSocket::Frame';

my $f = Protocol::WebSocket::Frame->new;

$f->append;
ok not defined $f->next;
$f->append('');
ok not defined $f->next;

$f->append(pack('H*', "810548656c6c6f"));
is $f->next_bytes, 'Hello';
is $f->opcode => 1;

$f->append(pack('H*',"818537fa213d7f9f4d5158"));
is $f->next_bytes, 'Hello';
is $f->opcode => 1;

$f->append(pack('H*', "010348656c"));
ok not defined $f->next_bytes;
$f->append(pack('H*', "80026c6f"));
is $f->next_bytes, 'Hello';
is $f->opcode => 1;

# Ping request
$f->append(pack('H*', "890548656c6c6f"));
is $f->next_bytes => 'Hello';
is $f->opcode => 9;

# Ping response
$f->append(pack('H*', "8a0548656c6c6f"));
is $f->next_bytes => 'Hello';
is $f->opcode => 10;

# 256 bytes
$f->append(pack('H*', "827E0100" . ('05' x 256)));
is(length $f->next_bytes, 256);
is $f->opcode => 2;

# 64KiB
$f->append(pack('H*', "827F0000000000010000" . ('05' x 65536)));
is(length $f->next_bytes, 65536);
is $f->opcode => 2;

$f = Protocol::WebSocket::Frame->new('Hello');
is $f->to_bytes => pack('H*', "810548656c6c6f");

$f = Protocol::WebSocket::Frame->new(buffer => 'Hello', masked => 1, mask => '939139389');
is $f->to_bytes, pack('H*',"818537fa213d7f9f4d5158");

# 256 bytes
$f = Protocol::WebSocket::Frame->new(
    buffer => pack('H*', ('05' x 256)),
    opcode => 2
);
is $f->to_bytes => pack('H*', "827E0100" . ('05' x 256));

# 64KiB bytes
$f = Protocol::WebSocket::Frame->new(
    buffer => pack('H*', ('05' x 65536)),
    opcode => 2
);
is $f->to_bytes => pack('H*', "827F0000000000010000" . ('05' x 65536));

$f = Protocol::WebSocket::Frame->new;
$f->append(Protocol::WebSocket::Frame->new('привет')->to_bytes);
is $f->next => 'привет';
