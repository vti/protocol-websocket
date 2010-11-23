package Protocol::WebSocket::Cookie::Response;

use strict;
use warnings;

use base 'Protocol::WebSocket::Cookie';

sub parse {
    my $self = shift;

    $self->SUPER::parse(@_);
}

sub to_string {
    my $self = shift;

    my $pairs = [];

    push @$pairs, [$self->{name}, $self->{value}];

    push @$pairs, ['Comment', $self->{comment}] if defined $self->{comment};

    push @$pairs, ['CommentURL', $self->{comment_url}]
      if defined $self->{comment_url};

    push @$pairs, ['Discard'] if $self->{discard};

    push @$pairs, ['Max-Age' => $self->{max_age}] if defined $self->{max_age};

    push @$pairs, ['Path'    => $self->{path}]    if defined $self->{path};

    if (defined $self->{portlist}) {
        $self->{portlist} = [$self->{portlist}]
          unless ref $self->{portlist} eq 'ARRAY';
        my $list = join ' ' => @{$self->{portlist}};
        push @$pairs, ['Port' => "\"$list\""];
    }

    push @$pairs, ['Secure'] if $self->{secure};

    push @$pairs, ['Version' => '1'];

    $self->pairs($pairs);

    return $self->SUPER::to_string;
}

1;
