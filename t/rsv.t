#!/usr/bin/env perl

use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib "$Bin/../t";
use strict;
use warnings;

use utf8;

use Test::More;

use Encode;

use_ok 'Protocol::WebSocket::Frame';

my $f = Protocol::WebSocket::Frame->new(
    buffer => '☺',
    rsv    => [0, 0, 0]
);
is substr($f->to_bytes, 0, 1) => "\x81";

$f = Protocol::WebSocket::Frame->new(
    buffer => '☺',
    rsv    => [0, 0, 1]
);
is substr($f->to_bytes, 0, 1) => "\x91";

$f = Protocol::WebSocket::Frame->new(
    buffer => '☺',
    rsv    => [0, 1, 0]
);
is substr($f->to_bytes, 0, 1) => "\xa1";

$f = Protocol::WebSocket::Frame->new(
    buffer => '☺',
    rsv    => [1, 0, 0]
);
is substr($f->to_bytes, 0, 1) => "\xc1";

$f = Protocol::WebSocket::Frame->new(
    buffer => '☺',
    rsv    => [1, 0, 1]
);
is substr($f->to_bytes, 0, 1) => "\xd1";

$f = Protocol::WebSocket::Frame->new(
    buffer => '☺',
    rsv    => [1, 1, 0]
);
is substr($f->to_bytes, 0, 1) => "\xe1";

$f = Protocol::WebSocket::Frame->new(
    buffer => '☺',
    rsv    => [1, 1, 1]
);
is substr($f->to_bytes, 0, 1) => "\xf1";

done_testing();
