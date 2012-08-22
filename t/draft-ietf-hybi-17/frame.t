#!/usr/bin/env perl

use strict;
use warnings;

use utf8;

use Test::More tests => 40;

use Encode;

use_ok 'Protocol::WebSocket::Frame';

my $f = Protocol::WebSocket::Frame->new;

is $f->version, 'draft-ietf-hybi-17';

$f->append;
ok not defined $f->next;
$f->append('');
ok not defined $f->next;

# Not masked
$f->append(pack('H*', "810548656c6c6f"));
is $f->next_bytes, 'Hello';
is $f->opcode => 1;
ok $f->is_text;

# Multi
$f->append(pack('H*', "810548656c6c6f") . pack('H*', "810548656c6c6f"));
is $f->next_bytes, 'Hello';
is $f->next_bytes, 'Hello';

# Masked
$f->append(pack('H*', "818537fa213d7f9f4d5158"));
is $f->next_bytes, 'Hello';
is $f->opcode => 1;

# Fragments
$f->append(pack('H*', "010348656c"));
ok not defined $f->next_bytes;
$f->append(pack('H*', "80026c6f"));
is $f->next_bytes, 'Hello';
is $f->opcode => 1;

# Multi fragments
$f->append(pack('H*', "010348656c") . pack('H*', "80026c6f"));
is $f->next_bytes, 'Hello';
is $f->opcode => 1;

# Injected control frame (1 fragment, ping, 2 fragment)
$f->append(pack('H*', "010348656c"));
$f->append(pack('H*', "890548656c6c6f"));
$f->append(pack('H*', "80026c6f"));
is $f->next_bytes, 'Hello';
is $f->opcode => 9;
is $f->next_bytes, 'Hello';
is $f->opcode => 1;

# Too many fragments
$f->append(pack('H*', "010348656c")) for 1 .. 129;
eval { $f->next_bytes };
ok $@;

# Ping request
$f = Protocol::WebSocket::Frame->new;
$f->append(pack('H*', "890548656c6c6f"));
is $f->next_bytes => 'Hello';
is $f->opcode     => 9;
ok $f->is_ping;

# Ping response
$f->append(pack('H*', "8a0548656c6c6f"));
is $f->next_bytes => 'Hello';
is $f->opcode     => 10;
ok $f->is_pong;

# 256 bytes
$f->append(pack('H*', "827E0100" . ('05' x 256)));
is(length $f->next_bytes, 256);
is $f->opcode => 2;
ok $f->is_binary;

# 64KiB
$f->append(pack('H*', "827F0000000000010000" . ('05' x 65536)));
is(length $f->next_bytes, 65536);
is $f->opcode => 2;

# Too big frame
$f->append(pack('H*', "827F0000000000100000" . ('05' x (65536 + 1))));
eval { $f->next_bytes };
ok $@;

$f = Protocol::WebSocket::Frame->new('Hello');
is $f->to_bytes => pack('H*', "810548656c6c6f");

$f = Protocol::WebSocket::Frame->new(
    buffer => 'Hello',
    masked => 1,
    mask   => '939139389'
);
is $f->to_bytes, pack('H*', "818537fa213d7f9f4d5158");

# Ping
$f = Protocol::WebSocket::Frame->new(buffer => 'Hello', type => 'ping');
is $f->to_bytes => pack('H*', "890548656c6c6f");

# 256 bytes
$f = Protocol::WebSocket::Frame->new(
    buffer => pack('H*', ('05' x 256)),
    type => 'binary'
);
is $f->to_bytes => pack('H*', "827E0100" . ('05' x 256));

# 64KiB bytes
$f = Protocol::WebSocket::Frame->new(
    buffer => pack('H*', ('05' x 65536)),
    type => 'binary'
);
is $f->to_bytes => pack('H*', "827F0000000000010000" . ('05' x 65536));

$f = Protocol::WebSocket::Frame->new;
$f->append(Protocol::WebSocket::Frame->new('привет')->to_bytes);
is $f->next => 'привет';

# Too big
$f = Protocol::WebSocket::Frame->new(
    buffer => pack('H*', ('05' x (65536 + 1))),
    type => 'binary'
);
eval { $f->to_bytes };
ok $@;
