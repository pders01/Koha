#!/usr/bin/perl

# Copyright (C) 2024 KohaAloha Ltd.
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <https://www.gnu.org/licenses>.

# Verify that yarn.lock is consistent with package.json and the Yarn
# configuration. If this test fails, run 'yarn install' and commit the
# resulting yarn.lock changes.

use Modern::Perl;
use Cwd           qw(getcwd);
use File::Compare qw(compare);
use File::Copy    qw(copy);
use File::Temp    qw(tempdir);
use Test::More tests => 2;
use Test::NoWarnings;

# Yarn 4 removed the read-only 'yarn check' command. An immutable install
# performs the link step and cannot safely reuse KTD's root-owned node_modules.
# Generate a candidate lockfile in an isolated project instead. The
# update-lockfile mode skips linking and does not create node_modules.
my $tempdir = tempdir( CLEANUP => 1 );
my @files   = qw(package.json yarn.lock);
push @files, ".yarnrc.yml" if -e ".yarnrc.yml";
for my $file (@files) {
    copy( $file, "$tempdir/$file" ) or BAIL_OUT("Cannot copy $file to $tempdir");
}

my $current_dir = getcwd();
chdir $tempdir or BAIL_OUT("Cannot change directory to $tempdir");
my $rc = system( "yarn", "install", "--mode=update-lockfile" );
chdir $current_dir or BAIL_OUT("Cannot change directory to $current_dir");

# Fail if Yarn cannot resolve the project or if it changes the lockfile.
my $lockfile_is_current = $rc == 0 && compare( "yarn.lock", "$tempdir/yarn.lock" ) == 0;
ok( $lockfile_is_current, "verify yarn.lock file is updated correctly" );
