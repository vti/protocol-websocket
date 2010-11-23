package Protocol::WebSocket::Cookie::Request;

use strict;
use warnings;

use base 'Protocol::WebSocket::Cookie';

sub parse {
    my $self = shift;

    $self->SUPER::parse(@_);

    my $cookies = [];

    my $pair = shift @{$self->pairs};
    my $version = $pair->[1];

    my $cookie;
    foreach my $pair (@{$self->pairs}) {
        next unless defined $pair->[0];

        if ($pair->[0] =~ m/^[^\$]/) {
            push @$cookies, $cookie if defined $cookie;

            $cookie = $self->_build_cookie(
                name    => $pair->[0],
                value   => $pair->[1],
                version => $version
            );
        }
        elsif ($pair->[0] eq '$Path') {
            $cookie->path($pair->[1]);
        }
        elsif ($pair->[0] eq '$Domain') {
            $cookie->domain($pair->[1]);
        }
    }

    push @$cookies, $cookie if defined $cookie;

    return $cookies;
}

sub _build_cookie { shift; Protocol::WebSocket::Cookie::Request->new(@_) }

sub name    { @_ > 1 ? $_[0]->{name}    = $_[1] : $_[0]->{name} }
sub value   { @_ > 1 ? $_[0]->{value}   = $_[1] : $_[0]->{value} }
sub version { @_ > 1 ? $_[0]->{version} = $_[1] : $_[0]->{version} }
sub path    { @_ > 1 ? $_[0]->{path}    = $_[1] : $_[0]->{path} }
sub domain  { @_ > 1 ? $_[0]->{domain}  = $_[1] : $_[0]->{domain} }

1;
