use ExtUtils::MakeMaker;
WriteMakefile
(
	NAME         => 'CGI::Cookie::Splitter',
	VERSION_FROM => 'lib/CGI/Cookie/Splitter.pm',
	INSTALLDIRS  => 'site',
	PL_FILE      => {},
	SIGN         => 1,
	PREREQ_PM    => {
		'CGI::Simple'   => '0',
		'Test::use::ok' => '0',
	},
)
;
