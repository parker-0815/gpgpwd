#!/usr/bin/perl
use strict;
use warnings;
use 5.010;
use Test::More tests => 30;
use File::Temp qw(tempdir);
use FindBin;
use Cwd qw(realpath);
use lib $FindBin::Bin;
use TestLib;

my $tmpdir = tempdir('gpgpwdt-XXXXXXXX',TMPDIR => 1, CLEANUP => 1);
my $secondTmpdir = tempdir('gpgpwdt-XXXXXXXX',TMPDIR => 1, CLEANUP => 1);

$ENV{XDG_CONFIG_HOME} = $tmpdir;

enable_raw_gpgpwd();

eSpawn(qw(add testpassword));
t_expect('Password> ','Password prompt');
expect_send("1234567890\n");
t_exitvalue(0,'Adding should succeed');

eSpawn('git','init');
t_expect('-re','Git repository initialized in.*','Success message');
t_exitvalue(0,'Init should succeed');
ok(-d $ENV{XDG_CONFIG_HOME}.'/gpgpwd/gitrepo','Git repo dir should be created');
ok(-d $ENV{XDG_CONFIG_HOME}.'/gpgpwd/gitrepo/.git','Git repo dir should contain .git');

# Git should have been enabled
eSpawn('config','git');
t_expect('git=auto','Git should have been enabled');
t_exitvalue(0,'Config retrieval should succeed');

# Switch to a clean root
$ENV{XDG_CONFIG_HOME} = $secondTmpdir;

eSpawn('git','clone',$tmpdir.'/gpgpwd/gitrepo');
t_expect('-re','Git repository initialized in.*','Success message');
t_exitvalue(0,'Clone should succeed');
ok(-d $ENV{XDG_CONFIG_HOME}.'/gpgpwd/gitrepo','Git repo dir should be created');
ok(-d $ENV{XDG_CONFIG_HOME}.'/gpgpwd/gitrepo/.git','Git repo dir should contain .git');

ok(-l $ENV{XDG_CONFIG_HOME}.'/gpgpwd/gpgpwd.db','Base gpgpwd.db should be a symlink');
is(realpath($ENV{XDG_CONFIG_HOME}.'/gpgpwd/gpgpwd.db'),$ENV{XDG_CONFIG_HOME}.'/gpgpwd/gitrepo/gpgpwd.db','Base gpgpwd.db should be symlinked to the git gpgpwd.db');

# Git should have been enabled
eSpawn('config','git');
t_expect('git=auto','Git should have been enabled');
t_exitvalue(0,'Config retrieval should succeed');

# Verify that it is using the correct file
eSpawn('--debuginfo');
t_expect('Data file                   : '.$secondTmpdir.'/gpgpwd/gitrepo/gpgpwd.db','Should be using the git data file');
t_expect('-re','flags\s+:\s+.*enableGit.*','It should auto-enable git');
t_exitvalue(0,'Debuginfo request should succeed');

# Should be able to retrieve the password that we just cloned
eSpawn(qw(get testpassword));
t_expect('testpassword        : 1234567890','Retrieve password');
t_exitvalue(0,'Retrieval command should succeed');

# Change the test password
eSpawn(qw(set testpassword));
t_expect('Password> ','Password prompt');
expect_send("12x4567890\n");
t_exitvalue(0,'Changing should succeed');

# Switch back to the initial root
$ENV{XDG_CONFIG_HOME} = $tmpdir;

# Add the clone as origin
eSpawn('git','remote','--','add','-f','-t','master','origin', $secondTmpdir.'/gpgpwd/gitrepo');
t_exitvalue(0,'Adding the remote should succeed');

eSpawn('git','remote');
t_expect('origin','Origin remote should exist');
t_exitvalue(0,'git remote command should succeed');

# Should be able to retrieve the password from upstream
eSpawn(qw(--no-xclip get testpassword));
t_expect('testpassword        : 1234567890','Retrieve old password');
t_expect('File updated by git, re-reading passwords:','Should re-read the password list due to git');
t_expect('testpassword        : 12x4567890','Retrieve new password');
t_exitvalue(0,'Retrieval command should succeed');