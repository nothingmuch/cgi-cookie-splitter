#!/usr/bin/perl -w

use strict;

use Module::Build;

Module::Build->new(
	module_name => 'CGI::Cookie::Splitter',
	license => 'perl',
	requires => {
		'CGI::Simple::Util' => 0,
		'Test::use::ok'     => 0,
	},
	create_makefile_pl => 'traditional',
	sign => 1,
)->create_build_script;

