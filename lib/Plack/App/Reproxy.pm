package Plack::App::Reproxy;
use strict;
use warnings;
use parent 'Plack::Component';
use Plack::Util::Accessor qw/backend/;

our $VERSION = '0.01';

use Plack::Request;
use AnyEvent;
use AnyEvent::HTTP;

sub call {
    my ($self, $env) = @_;

    my $req = Plack::Request->new($env);

    my $res = AE::cv;

    my $uri     = URI->new( $self->backend . $req->uri->path_query );
    my %headers = map { $_ => $req->header($_) } $req->headers->header_field_names;

    my $proxy_method  = $req->method;
    my $proxy_uri     = $uri;
    my $proxy_headers = \%headers;
    my $proxy_content = $req->raw_body;
    my $proxy_callback;

    my $proxy; $proxy = sub {
        http_request(
            $proxy_method => $proxy_uri,
            headers       => $proxy_headers,
            $proxy_content ? (body => $proxy_content) : (),
            sub {
                my ($body, $hdr) = @_;

                my $status = delete $hdr->{Status};

                if ($status =~ /^59/) {
                    # internal error
                    warn "Proxy error: $status $hdr->{Reason}, $hdr->{URL}";
                    $res->send([
                        500,
                        [ 'Content-Length' => 21, 'Content-Type' => 'text/plain' ],
                        ['Internal Server Error'],
                    ]);
                }
                else {
                    # remove pseudo-headers
                    delete @$hdr{qw/HTTPVersion Reason URL/};

                    if ($hdr->{'x-reproxy-url'}) {
                        # reproxy
                        $proxy_method = $hdr->{'x-reproxy-method'} || 'GET';
                        $proxy_uri    = $hdr->{'x-reproxy-url'};
                        $proxy_headers = {};
                        for my $h (grep /^x-reproxy-header-/, keys %$hdr) {
                            (my $n = $h) =~ s/^x-reproxy-header-//;
                            $proxy_headers->{$n} = $hdr->{$h};
                        }
                        $proxy_content  = $body;
                        $proxy_callback = $hdr->{'x-reproxy-callback'};

                        my $t; $t = AnyEvent->timer(
                            after => 0,
                            cb    => sub {
                                undef $t;
                                $proxy->();
                            },
                        );
                    }
                    elsif ($proxy_callback) {
                        $proxy_method = 'POST';
                        $proxy_uri    = $proxy_callback;
                        $proxy_headers = $hdr;
                        $proxy_content = $body;
                        undef $proxy_callback;

                        my $t; $t = AnyEvent->timer(
                            after => 0,
                            cb    => sub {
                                undef $t;
                                $proxy->();
                            },
                        );
                    }
                    else {
                        $res->send([
                            $status,
                            [%$hdr],
                            [$body || ''],
                        ]);
                    }
                }
            },
        );
    };
    $proxy->();

    $res;
}

1;

__END__

=head1 NAME

Plack::App::Reproxy - Module abstract (<= 44 characters) goes here

=head1 SYNOPSIS

    # app.psgi
    use Plack::App::Reproxy;
    my $app = Plack::App::FCGIDispatcher->new({
        backend => 'http://127.0.0.1:5001',
    })->to_app;

=head1 DESCRIPTION

Stub documentation for this module was created by ExtUtils::ModuleMaker.
It looks like the author of the extension was negligent enough
to leave the stub unedited.

Blah blah blah.

=head1 AUTHOR

Daisuke Murase <typester@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2009 by KAYAC Inc.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
