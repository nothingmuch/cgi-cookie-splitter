use ExtUtils::MakeMaker;
WriteMakefile
(
          'NAME' => 'CGI::Cookie::Splitter',
          'VERSION_FROM' => 'lib/CGI/Cookie/Splitter.pm',
          'PREREQ_PM' => {
                           'CGI::Simple'   => '0',
                           'Test::use::ok' => '0'
                         },
          'INSTALLDIRS' => 'site',
          'PL_FILES' => {}
        )
;
