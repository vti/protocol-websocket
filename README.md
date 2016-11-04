# NAME

Protocol::WebSocket - WebSocket protocol

# SYNOPSIS

    # Server side
    my $hs = Protocol::WebSocket::Handshake::Server->new;

    $hs->parse('some data from the client');

    $hs->is_done; # tells us when handshake is done

    my $frame = $hs->build_frame;

    $frame->append('some data from the client');

    while (defined(my $message = $frame->next)) {
        if ($frame->is_close) {

            # Send close frame back
            send(
                $hs->build_frame(
                    type    => 'close',
                    version => $version
                )->to_bytes
            );

            return;
        }

        # We got a message!
    }

# DESCRIPTION

Client/server WebSocket message and frame parser/constructor. This module does
not provide a WebSocket server or client, but is made for using in http servers
or clients to provide WebSocket support.

[Protocol::WebSocket](https://metacpan.org/pod/Protocol::WebSocket) supports the following WebSocket protocol versions:

    draft-ietf-hybi-17 (latest)
    draft-ietf-hybi-10
    draft-ietf-hybi-00 (with HAProxy support)
    draft-hixie-75

By default the latest version is used. The WebSocket version is detected
automatically on the server side. On the client side you have set a `version`
attribute to an appropriate value.

[Protocol::WebSocket](https://metacpan.org/pod/Protocol::WebSocket) itself does not contain any code and cannot be used
directly. Instead the following modules should be used:

## High-level modules

### [Protocol::WebSocket::Server](https://metacpan.org/pod/Protocol::WebSocket::Server)

Server helper class.

### [Protocol::WebSocket::Client](https://metacpan.org/pod/Protocol::WebSocket::Client)

Client helper class.

## Low-level modules

### [Protocol::WebSocket::Handshake::Server](https://metacpan.org/pod/Protocol::WebSocket::Handshake::Server)

Server handshake parser and constructor.

### [Protocol::WebSocket::Handshake::Client](https://metacpan.org/pod/Protocol::WebSocket::Handshake::Client)

Client handshake parser and constructor.

### [Protocol::WebSocket::Frame](https://metacpan.org/pod/Protocol::WebSocket::Frame)

WebSocket frame parser and constructor.

### [Protocol::WebSocket::Request](https://metacpan.org/pod/Protocol::WebSocket::Request)

Low level WebSocket request parser and constructor.

### [Protocol::WebSocket::Response](https://metacpan.org/pod/Protocol::WebSocket::Response)

Low level WebSocket response parser and constructor.

### [Protocol::WebSocket::URL](https://metacpan.org/pod/Protocol::WebSocket::URL)

Low level WebSocket url parser and constructor.

# EXAMPLES

For examples on how to use [Protocol::WebSocket](https://metacpan.org/pod/Protocol::WebSocket) with various event loops see
`examples/` directory in the distribution.

# CREDITS

In order of appearance:

Paul "LeoNerd" Evans

Jon Gentle

Lee Aylward

Chia-liang Kao

Atomer Ju

Chuck Bredestege

Matthew Lien (BlueT)

Joao Orui

Toshio Ito (debug-ito)

Neil Bowers

Michal Špaček

Graham Ollis

Anton Petrusevich

# AUTHOR

Viacheslav Tykhanovskyi, `vti@cpan.org`.

# COPYRIGHT

Copyright (C) 2010-2014, Viacheslav Tykhanovskyi.

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl 5.10.
