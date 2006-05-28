#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';

use ok "CGI::Cookie::Splitter";

use CGI::Simple::Cookie;

my @cases = ( # big numbers are used to mask the overhead of the other fields
	{
		size_limit => 1000,
		num_cookies => 11,
		-name => "moosen",
		-value => ("a" x 10_000),
	},
	{
		size_limit => 1000,
		num_cookies => 11,
		-name => "moosen",
		-domain => ".foo.com",
		-value => [ ("a" x 1000) x 10 ],
	},
	{
		size_limit => 1000,
		num_cookies => 14, # feck
		-name => "moosen",
		-path => "/bar/gorch",
		-value => [ ("a" x 10) x 1000 ],
	},
	{
		size_limit => 1000,
		num_cookies => 3,
		-name => "moosen",
		secure => 1,
		-value => { foo => ("a" x 1000), bar => ("b" x 1000) },
	},
);

foreach my $case ( @cases ) {
	my ( $size_limit, $num_cookies ) = delete @{ $case }{qw/size_limit num_cookies/};

	my $big = CGI::Simple::Cookie->new(%$case);

	can_ok( "CGI::Cookie::Splitter", "new" );

	my $splitter = CGI::Cookie::Splitter->new( size => $size_limit ); # 50 is padding for the other attrs

	isa_ok( $splitter, "CGI::Cookie::Splitter" );

	can_ok( $splitter, "split" );

	my @small = $splitter->split( $big );

	is( scalar(@small), $num_cookies, "returned several smaller cookies" );

	my $i = 0;
	foreach my $cookie ( @small ) {
		cmp_ok( length($cookie->as_string), "<=", $size_limit, "cookie size is under specified limit" );
		is_deeply( [ $splitter->demangle_name($cookie->name) ], [ $big->name => $i++ ], "name mangling looks good (" . $cookie->name . ")" );
	}

	my @big = $splitter->join( @small );

	is( scalar(@big), 1, "one big cookie from small cookies" );

	foreach my $field ( qw/name value domain path secure/ ) {
		is_deeply( [ $big[0]->$field ], [ $big->$field ], "'$field' is the same" );
	}
}
