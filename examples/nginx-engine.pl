#!/usr/bin/env perl

use strict;
use warnings;

use Nginx::Engine;

use Protocol::WebSocket::Handshake::Server;
use Protocol::WebSocket::Frame;

ngxe_init("", 0, 64);

ngxe_server(
    "*" => 3000 => sub {
        my $id = shift;

        my $hs    = Protocol::WebSocket::Handshake::Server->new;
        my $frame = Protocol::WebSocket::Frame->new;

        ngxe_reader(
            $id => 0 => 5000 => sub {
                my ($id, $error, $recv, $send) = @_;

                return if $error;

                if (!$hs->is_done) {
                    $hs->parse($recv);

                    if (my $e = $hs->error) {
                        warn "Websocket error '$e'";
                        return;
                    }

                    if ($hs->is_done) {
                        $send .= $hs->to_string;
                    }
                }
                else {
                    $frame->append($recv);

                    while (my $message = $frame->next) {
                        $send .= $frame->new($message)->to_bytes;
                    }
                }

                $_[2] = $recv;
                $_[3] = $send;

                # switching to writer
                ngxe_reader_stop($id);
                ngxe_writer_start($id);
            }
        );

        ngxe_writer(
            $id => 0 => 1000 => "" => sub {
                my ($id, $error) = @_;

                return if $error;

                # switching back to reader
                ngxe_writer_stop($id);
                ngxe_reader_start($id);
            }
        );

        ngxe_reader_start($id);
    }
);

ngxe_loop;
