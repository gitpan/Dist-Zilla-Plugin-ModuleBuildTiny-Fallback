use strict;
use warnings FATAL => 'all';

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::DZil;
use Test::Fatal;
use Path::Tiny;
use Test::Deep;

use Test::Requires { 'Dist::Zilla::Plugin::CheckBin' => '0.004' };

my $tzil = Builder->from_config(
    { dist_root => 't/does-not-exist' },
    {
        add_files => {
            path(qw(source dist.ini)) => simple_ini(
                [ GatherDir => ],
                [ MetaConfig => ],
                [ 'ModuleBuildTiny::Fallback' ],
                [ CheckBin => { command => 'ls' } ],
            ),
            path(qw(source lib Foo.pm)) => "package Foo;\n1;\n",
        },
    },
);

$tzil->chrome->logger->set_debug(1);
is(
    exception { $tzil->build },
    undef,
    'build proceeds normally',
);

SKIP: {
    skip 'older [ModuleBuildTiny] did not create Build.PL beforehand, so other plugins do not have a chance to insert content first', 2
        if not eval { Dist::Zilla::Plugin::ModuleBuildTiny->VERSION(0.008); 1 };
    cmp_deeply(
        $tzil->log_messages,
        superbagof(
            '[ModuleBuildTiny::Fallback] something else changed the content of the Module::Build::Tiny version of Build.PL -- maybe you should switch back to [ModuleBuildTiny]?'
        ),
        'build warned that some extra content was added to Build.PL, possibly making this plugin inadvisable',
    );

    like(
        $tzil->slurp_file('build/Build.PL'),
    qr/^\s+# This section for DZT-Sample was generated by Dist::Zilla::Plugin::ModuleBuildTiny [\d.]+\.
    use strict;
    use warnings;

    # inserted by Dist::Zilla::Plugin::CheckBin [\d.]+
    use Devel::CheckBin;
    check_bin\('ls'\);$/m,
        'additional Build.PL content is in the Module::Build::Tiny section',
    );
}

diag 'got log messages: ', explain $tzil->log_messages
    if not Test::Builder->new->is_passing;

done_testing;
