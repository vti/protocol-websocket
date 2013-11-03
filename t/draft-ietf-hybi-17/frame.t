#!/usr/bin/env perl

use strict;
use warnings;

use utf8;

use Test::More;

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

# initialize fin flag to zero
$f = Protocol::WebSocket::Frame->new(buffer => 'Hello', fin => 0);
is $f->to_bytes => pack('H*', "010548656c6c6f");

# continuation frame
$f = Protocol::WebSocket::Frame->new(buffer => "Hello", type => "continuation");
is $f->to_bytes => pack('H*', "800548656c6c6f");

# generate fragmented frames
$f = Protocol::WebSocket::Frame->new();
$f->append(
    Protocol::WebSocket::Frame->new(
        buffer => "Hello",
        type   => "binary",
        fin    => 0
    )->to_bytes
);
is $f->next_bytes => undef;
$f->append(
    Protocol::WebSocket::Frame->new(
        buffer => ", ",
        type   => "continuation",
        fin    => 0
    )->to_bytes
);
is $f->next_bytes => undef;
$f->append(
    Protocol::WebSocket::Frame->new(
        buffer => "World!",
        type   => "continuation",
        fin    => 1
    )->to_bytes
);
is $f->next_bytes => "Hello, World!";
is $f->opcode     => 2;

subtest 'constructor type values and is_$type are consistent' => sub {
    my @types = qw(continuation text binary ping pong close);
    foreach my $type (@types) {
        my $f = Protocol::WebSocket::Frame->new(type => $type);
        foreach my $test_type (@types) {
            my $method = "is_$test_type";
            if ($type eq $test_type) {
                ok $f->$method, "type $type $method";
            }
            else {
                ok !$f->$method, "type $type not $method";
            }
        }
    }
};

subtest 'opcode accessor/mutator' => sub {
    my $f = Protocol::WebSocket::Frame->new("Hello");
    is $f->opcode => 1;
    is $f->to_bytes => pack('H*', "810548656c6c6f");

    $f->opcode(2);
    is $f->opcode => 2;
    is $f->to_bytes => pack('H*', "820548656c6c6f");

    $f->opcode(0);
    is $f->opcode => 0;
    is $f->to_bytes => pack('H*', "800548656c6c6f");
};

subtest 'opcode immediately available' => sub {
    my $f = Protocol::WebSocket::Frame->new(buffer => "Hello", opcode => 8);

    is $f->opcode => 8;
    is $f->to_bytes => pack('H*', "880548656c6c6f");
};

subtest 'if both type and opcode are specified in new(), type wins' => sub {
    my $f = Protocol::WebSocket::Frame->new(
        buffer => "Hello",
        type   => "ping",
        opcode => 2
    );

    is $f->opcode => 9;
    is $f->to_bytes => pack('H*', "890548656c6c6f");
};

subtest 'mask frame' => sub {
    foreach my $test_case (
        {label => "foobar", opcode => 9, buffer => "Foobar"},
        {label => "empty", opcode => 1, buffer => ""},
        {label => "character zero", opcode => 2, buffer => "0"},
        {label => "number zero", opcode => 2, buffer => 0},
        {label => "number 123", opcode => 1, buffer => 123},
    ) {
        my $f = Protocol::WebSocket::Frame->new(
            buffer => $test_case->{buffer},
            opcode => $test_case->{opcode},
            masked => 1
        );
        my $frame_bytestring = $f->to_bytes;
        my @frame_bytes = unpack("C*", $frame_bytestring);
        ok $frame_bytes[1] & 0x80, "$test_case->{label}: MASK bit is set";
            
        my $p = Protocol::WebSocket::Frame->new();
        $p->append($frame_bytestring);
        my $message = $p->next_bytes;
        is $message   => $test_case->{buffer}, "$test_case->{label}: parse buffer OK";
        is $p->opcode => $test_case->{opcode}, "$test_case->{label}: parse opcode OK";
    }
};

subtest 'append is destructive' => sub {
    my $f = Protocol::WebSocket::Frame->new();

    my $chunk = pack('H*', "810548656c6c6f");
    $f->append($chunk);

    is $chunk => "", "append() is destructive";
};

done_testing;
