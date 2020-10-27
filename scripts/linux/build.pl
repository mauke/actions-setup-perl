#!/usr/bin/env perl

use utf8;
use warnings;
use strict;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Try::Tiny;
use Perl::Build;
use File::Spec;
use version 0.77 ();
use Actions::Core qw/group set_failed/;

sub run {
    my $version = $ENV{PERL_VERSION};
    my $install_dir = File::Spec->catdir($ENV{RUNNER_TOOL_CACHE}, "perl", $version, "x64");
    my $tmpdir = $ENV{RUNNER_TEMP};

    group "build perl $version" => sub {
        local $ENV{PERL5_PATCHPERL_PLUGIN} = "GitHubActions";

        # get the number of CPU cores to parallel make
        my $jobs = `nproc` + 0; # evaluate `nproc` in number context
        if ($jobs <= 0 || version->parse("v$version") < version->parse("v5.20.0") ) {
            # Makefiles older than v5.20.0 could break parallel make.
            $jobs = 1;
        }

        Perl::Build->install_from_cpan(
            $version => (
                dst_path          => $install_dir,
                configure_options => ["-de", "-Dman1dir=none", "-Dman3dir=none"],
                jobs              => $jobs,
            )
        );
    };

    group "perl -V" => sub {
        system(File::Spec->catfile($install_dir, 'bin', 'perl'), '-V') == 0 or die "$!";
    };

    group "archiving" => sub {
        chdir $install_dir or die "failed to cd $install_dir: $!";
        system("tar", "Jcvf", "$tmpdir/perl.tar.xz", ".") == 0
            or die "failed to archive";
    };
}

try {
    run();
} catch {
    set_failed("$_");
};

1;
