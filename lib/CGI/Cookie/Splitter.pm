#!/usr/bin/perl

package CGI::Cookie::Splitter;

use strict;
use warnings;

use vars qw/$VERSION/;
$VERSION = "0.01";

use Scalar::Util qw/blessed/;
use CGI::Simple::Util qw/escape unescape/;
use Carp qw/croak/;

sub new {
	my ( $class, %params ) = @_;

	$params{size} = 4096 unless exists $params{size};

	croak "size has to be a positive integer ($params{size} is invalid)"
		unless $params{size} =~ /^\d+$/ and $params{size} > 1;

	bless \%params, $class;
}

sub size { $_[0]{size} }

sub split {
	my ( $self, @cookies ) = @_;
	map { $self->split_cookie($_) } @cookies;
}

sub split_cookie {
	my ( $self, $cookie ) = @_;
	return $cookie unless $self->should_split( $cookie );
	return $self->do_split_cookie(
		$self->new_cookie( $cookie,
			name => $self->mangle_name( $cookie->name, 0 ),
			value => CORE::join("&",map { escape($_) } $cookie->value) # simplifies the string splitting
		)
	);
}

sub do_split_cookie {
	my ( $self, $head ) = @_;

	my $tail = $self->new_cookie( $head, value => '', name => $self->mangle_name_next( $head->name ) );

	my $max_value_size = $self->size - ( $self->cookie_size( $head ) - length( escape($head->value) ) );
	$max_value_size -= 10; # account for overhead the cookie serializer might add

	die "Internal math error, please file a bug for CGI::Cookie::Splitter: max size should be > 0, but is $max_value_size (perhaps other attrs are too big?)"
		unless ( $max_value_size > 0 );

	my ( $head_v, $tail_v ) = $self->split_value( $max_value_size, $head->value );

	$head->value( $head_v );
	$tail->value( $tail_v );

	die "Internal math error, please file a bug for CGI::Cookie::Splitter"
		unless $self->cookie_size( $head ) <= $self->size; # 10 is not enough overhead

	return $head unless $tail_v;
	return ( $head, $self->do_split_cookie( $tail ) );
}

sub split_value {
	my ( $self, $max_size, $value ) = @_;

	my $adjusted_size = $max_size;

	my ( $head, $tail );

	return ( $value, '' ) if length($value) <= $adjusted_size;

	split_value: {
		croak "Can't reduce the size of the cookie anymore (adjusted = $adjusted_size, max = $max_size)" unless $adjusted_size > 0;

		$head = substr( $value, 0, $adjusted_size );
		$tail = substr( $value, $adjusted_size );

		if ( length(my $escaped = escape($head)) > $max_size ) {
			my $adjustment = int( ( length($escaped) - length($head) ) / 3 ) + 1;

			die "Internal math error, please file a bug for CGI::Cookie::Splitter"
				unless $adjustment;

			$adjusted_size -= $adjustment;
			redo split_value;
		}
	}

	return ( $head, $tail );
}

sub cookie_size {
	my ( $self, $cookie ) = @_;
	length( $cookie->as_string );
}

sub new_cookie {
	my ( $self, $cookie, %params ) = @_;

	for (qw/name secure path domain expires value/) {
		next if exists $params{$_};
		$params{"-$_"} = $cookie->$_;
	}

	blessed($cookie)->new( %params );
}

sub should_split {
	my ( $self, $cookie ) = @_;
	$self->cookie_size( $cookie ) > $self->size;
}

sub join {
	my ( $self, @cookies ) = @_;

	my %split;
	my @ret;

	foreach my $cookie ( @cookies ) {
		my ( $name, $index ) = $self->demangle_name( $cookie->name );
		if ( $name ) {
			$split{$name}[$index] = $cookie;
		} else {
			push @ret, $cookie;
		}
	}

	foreach my $name ( keys %split ) { 
		my $split_cookie = $split{$name};
		croak "The cookie $name is missing some chunks" if grep { !defined } @$split_cookie;
		push @ret, $self->join_cookie( $name => @$split_cookie );
	}

	return @ret;
}

sub join_cookie {
	my ( $self, $name, @cookies ) = @_;
	$self->new_cookie( $cookies[0], name => $name, value => $self->join_value( map { $_->value } @cookies ) );
}

sub join_value {
	my ( $self, @values ) = @_;
	return [ map { unescape($_) } split('&', CORE::join("", @values)) ];
}

sub mangle_name_next {
	my ( $self, $mangled ) = @_;
	my ( $name, $index ) = $self->demangle_name( $mangled );
	$self->mangle_name( $name, $index+1 ); # can't trust magic incr because it might overflow and fudge 'chunk'
}

sub mangle_name {
	my ( $self, $name, $index ) = @_;
	return sprintf '_bigcookie_%s_chunk%d', $name, $index;
}

sub demangle_name {
	my ( $self, $mangled_name ) = @_;
	my ( $name, $index ) = ( $mangled_name =~ /^_bigcookie_(.+?)_chunk(\d+)$/ );

	return ( $name, $index );
}

__PACKAGE__;

__END__

=pod

=head1 NAME

CGI::Cookie::Splitter - Split big cookies into smaller ones.

=head1 SYNOPSIS

	use CGI::Cookie::Splitter;

	my $splitter = CGI::Cookie::Splitter->new(
		size => 123, # defaults to 4096
	);

	@small_cookies = $splitter->split( @big_cookies );

	@big_cookies = $splitter->join( @small_cookies );

=head1 DESCRIPTION

RFC 2109 reccomends that the minimal cookie size supported by the client is
4096 bytes. This has become a pretty standard value, and if your server sends
larger cookies than that it's considered a no-no.

This module provides a pretty simple interface to generate small cookies that
are under a certain limit, without wasting too much effort.

=head1 METHODS

=over 4

=item new %params

The only supported parameters right now are C<size>. It defaults to 4096.

=item split @cookies

This method accepts a list of CGI::Cookie objects (or look alikes) and returns
a list of CGI::Cookies.

Whenever an object with a total size that is bigger than the limit specified at
construction time is encountered it is replaced in the result list with several
objects of the same class, which are assigned serial names and have a smaller
size and the same domain/path/expires/secure parameters.

=item join @cookies

This is the inverse of C<split>.

=item should_split $cookie

Whether or not the cookie should be split

=item mangle_name_next $name

Demangles name, increments the index and remangles.

=item mangle_name $name, $index

=item demangle_name $mangled_name

These methods encapsulate a name mangling scheme for changing the cookie names
to allo wa 1:n relationship.

The default mangling behavior is not 100% safe because cookies with a safe size
are not mangled.

As long as your cookie names don't start with the substring C<_bigcookie_> you
should be OK ;-)

=back

=head1 SUBCLASSING

This module is designed to be easily subclassed... If you need to split cookies
using a different criteria then you should look into that.

=head1 SEE ALSO

L<CGI::Cookie>, L<CGI::Simple::Cookie>, L<http://www.cookiecutter.com/>, RFC 2109

=head1 AUTHOR

Yuval Kogman, C<nothingmuch@woobling.org>

=head1 COPYRIGHT & LICENCE

        Copyright (c) 2006 the aforementioned authors. All rights
        reserved. This program is free software; you can redistribute
        it and/or modify it under the same terms as Perl itself.

=cut


