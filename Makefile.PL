#!/usr/bin/env perl

use strict;
use warnings;

use inc::Module::Install;

name 'Protocol-WebSocket';

version_from 'lib/Protocol/WebSocket.pm';
author 'Viacheslav Tykhanovskyi <vti@cpan.org>';
abstract 'WebSocket request/response';
license 'artistic_2';
perl_version '5.008007';

requires 'Carp'         => 0;
requires 'Digest::MD5'  => 0;
requires 'Digest::SHA1' => 0;
requires 'Scalar::Util' => 0;

tests 't/*.t t/*/*.t t/*/*/*.t t/*/*/*/*.t';

no_index directory => 't';

resources
  bugtracker => 'http://github.com/vti/protocol-websocket/issues',
  repository => 'http://github.com/vti/protocol-websocket/',
  license    => 'http://dev.perl.org/licenses/';

auto_install;

WriteAll;
