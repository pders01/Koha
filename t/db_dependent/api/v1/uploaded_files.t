#!/usr/bin/env perl

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
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Test::More tests => 5;
use Test::Mojo;
use Test::Warn;

use t::lib::TestBuilder;
use t::lib::Mocks;

use C4::Auth;
use C4::Context;
use Koha::UploadedFiles;
use Koha::Database;

use File::Temp qw(tempdir);
use File::Spec;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

# Set up upload directory
my $upload_dir = tempdir( CLEANUP => 1 );
t::lib::Mocks::mock_config( 'upload_path', $upload_dir );

subtest 'list() tests' => sub {

    plan tests => 19;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }     # no global permissions
        }
    );

    # Add the specific upload_general_files permission following Upload.t pattern
    $builder->build(
        {
            source => 'UserPermission',
            value  => {
                borrowernumber => $librarian->borrowernumber,
                module_bit     => 13,                           # tools module bit
                code           => 'upload_general_files',
            }
        }
    );

    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }     # NO permissions
        }
    );

    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $unauth_userid = $patron->userid;

    ## Authorized user tests
    # No uploaded files, so empty array should be returned
    $t->get_ok("//$userid:$password@/api/v1/uploaded_files")->status_is(200)->json_is( [] );

    # Create test uploaded files
    my $uploaded_file_1 = $builder->build_object(
        {
            class => 'Koha::UploadedFiles',
            value => {
                hashvalue => 'hash1',
                filename  => 'test1.txt',
                dir       => 'test',
                filesize  => 1000,
                owner     => $librarian->borrowernumber,
                public    => 0,
                permanent => 1
            }
        }
    );

    my $uploaded_file_2 = $builder->build_object(
        {
            class => 'Koha::UploadedFiles',
            value => {
                hashvalue => 'hash2',
                filename  => 'test2.txt',
                dir       => 'test',
                filesize  => 2000,
                owner     => $librarian->borrowernumber,
                public    => 1,
                permanent => 0
            }
        }
    );

    # Two files created, they should both be returned
    $t->get_ok("//$userid:$password@/api/v1/uploaded_files");

    if ( $t->tx->res->code != 200 ) {
        diag "Response status: " . $t->tx->res->code;
        diag "Response body: " . $t->tx->res->body;
    } else {
        diag "Success response body: " . $t->tx->res->body;
    }

    $t->status_is(200)->json_is( '/0/file_id' => $uploaded_file_1->id )
        ->json_is( '/1/file_id' => $uploaded_file_2->id );

    # Test filtering by public status
    $t->get_ok("//$userid:$password@/api/v1/uploaded_files?public=1")->status_is(200)->json_has('/0')->json_hasnt('/1')
        ->json_is( '/0/file_id' => $uploaded_file_2->id );

    # Test filtering by category
    my $uploaded_file_3 = $builder->build_object(
        {
            class => 'Koha::UploadedFiles',
            value => {
                hashvalue          => 'hash3',
                filename           => 'test3.txt',
                dir                => 'other_category',
                filesize           => 3000,
                owner              => $librarian->borrowernumber,
                uploadcategorycode => 'other_category',
                public             => 0,
                permanent          => 1
            }
        }
    );

    $t->get_ok("//$userid:$password@/api/v1/uploaded_files?category=other_category")->status_is(200)->json_has('/0')
        ->json_hasnt('/1')->json_is( '/0/file_id' => $uploaded_file_3->id );

    # Unauthorized access
    $t->get_ok("//$unauth_userid:$password@/api/v1/uploaded_files")->status_is(403);

    $schema->storage->txn_rollback;
};

subtest 'get() tests' => sub {

    plan tests => 8;

    $schema->storage->txn_begin;

    my $uploaded_file = $builder->build_object(
        {
            class => 'Koha::UploadedFiles',
            value => { public => 0 }          # Make it non-public for auth testing
        }
    );
    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }           # no global permissions
        }
    );

    # Add the specific upload_general_files permission following Upload.t pattern
    $builder->build(
        {
            source => 'UserPermission',
            value  => {
                borrowernumber => $librarian->borrowernumber,
                module_bit     => 13,                           # tools module bit
                code           => 'upload_general_files',
            }
        }
    );

    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }     # NO permissions
        }
    );

    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $unauth_userid = $patron->userid;

    # This file exists, should get returned
    $t->get_ok( "//$userid:$password@/api/v1/uploaded_files/" . $uploaded_file->id )->status_is(200)
        ->json_is( '/file_id' => $uploaded_file->id );

    # Unauthorized access
    $t->get_ok( "//$unauth_userid:$password@/api/v1/uploaded_files/" . $uploaded_file->id )->status_is(403);

    # Attempt to get non-existent file
    my $uploaded_file_to_delete = $builder->build_object( { class => 'Koha::UploadedFiles' } );
    my $non_existent_id         = $uploaded_file_to_delete->id;
    $uploaded_file_to_delete->delete;

    $t->get_ok("//$userid:$password@/api/v1/uploaded_files/$non_existent_id")->status_is(404)
        ->json_is( '/error' => 'File not found' );

    $schema->storage->txn_rollback;
};

subtest 'upload() tests' => sub {

    plan tests => 13;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }     # no global permissions
        }
    );

    # Add the specific upload_general_files permission following Upload.t pattern
    $builder->build(
        {
            source => 'UserPermission',
            value  => {
                borrowernumber => $librarian->borrowernumber,
                module_bit     => 13,                           # tools module bit
                code           => 'upload_general_files',
            }
        }
    );

    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }     # NO permissions
        }
    );
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $unauth_userid = $patron->userid;

    # Create a test file upload
    my $file_content = "This is a test file content";
    my $file_name    = "test_upload.txt";

    # Test successful upload
    $t->post_ok(
        "//$userid:$password@/api/v1/uploaded_files" => form => {
            file     => { content => $file_content, filename => $file_name },
            public   => 0,
            category => 'test_category'
        }
    )->status_is(201)->json_has('/file_id')->json_is( '/filename' => $file_name )->json_is( '/public' => 0 )
        ->json_is( '/category' => 'test_category' );

    my $file_id = $t->tx->res->json->{file_id};

    # Verify file was created in the database
    my $uploaded_file = Koha::UploadedFiles->find($file_id);
    is( $uploaded_file->filename, $file_name,            'File name stored correctly' );
    is( $uploaded_file->filesize, length($file_content), 'File size stored correctly' );

    # Test unauthorized upload
    $t->post_ok( "//$unauth_userid:$password@/api/v1/uploaded_files" => form =>
            { file => { content => $file_content, filename => $file_name } } )->status_is(403);

    # Test duplicate file upload (same hash)
    $t->post_ok(
        "//$userid:$password@/api/v1/uploaded_files" => form => {
            file     => { content => $file_content, filename => $file_name },
            category => 'test_category'
        }
    )->status_is(400)->json_is( '/error_code' => 'duplicate_file' );

    $schema->storage->txn_rollback;
};

subtest 'download() tests' => sub {

    plan tests => 12;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }     # no global permissions
        }
    );

    # Add the specific upload_general_files permission following Upload.t pattern
    $builder->build(
        {
            source => 'UserPermission',
            value  => {
                borrowernumber => $librarian->borrowernumber,
                module_bit     => 13,                           # tools module bit
                code           => 'upload_general_files',
            }
        }
    );

    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }     # NO permissions
        }
    );
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $unauth_userid = $patron->userid;

    # Create a test file
    my $file_content = "Test file content for download";
    my $filename     = "download_test.txt";
    my $hashvalue    = 'testhash123';
    my $category     = 'test_download';

    # Create directory
    my $dir = File::Spec->catdir( $upload_dir, $category );
    mkdir $dir unless -d $dir;

    # Write test file
    my $filepath = File::Spec->catfile( $dir, $hashvalue . '_' . $filename );
    open my $fh, '>', $filepath or die "Cannot write test file: $!";
    print $fh $file_content;
    close $fh;

    # Create database record
    my $uploaded_file = $builder->build_object(
        {
            class => 'Koha::UploadedFiles',
            value => {
                hashvalue          => $hashvalue,
                filename           => $filename,
                dir                => $category,
                filesize           => length($file_content),
                owner              => $librarian->borrowernumber,
                uploadcategorycode => $category,
                public             => 0,
                permanent          => 1
            }
        }
    );

    # Test successful download
    $t->get_ok( "//$userid:$password@/api/v1/uploaded_files/" . $uploaded_file->id . "/download" )->status_is(200)
        ->content_is($file_content)->header_is( 'Content-Type' => 'application/octet-stream' )
        ->header_like( 'Content-Disposition' => qr/attachment; filename="$filename"/ );

    # Test unauthorized download
    $t->get_ok( "//$unauth_userid:$password@/api/v1/uploaded_files/" . $uploaded_file->id . "/download" )
        ->status_is(403);

    # Test download of public file (should work for unauthorized user via public endpoint)
    $uploaded_file->public(1)->store;
    $t->get_ok( "/api/v1/public/uploaded_files/" . $uploaded_file->id . "/download" )->status_is(200)
        ->content_is($file_content);

    # Test non-existent file
    $uploaded_file->delete( { keep_file => 1 } );    # Delete DB record but keep file
    $t->get_ok( "//$userid:$password@/api/v1/uploaded_files/" . $uploaded_file->id . "/download" )->status_is(404);

    # Clean up
    unlink $filepath;

    $schema->storage->txn_rollback;
};

subtest 'delete() tests' => sub {

    plan tests => 10;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }     # no global permissions
        }
    );

    # Add the specific upload_general_files permission following Upload.t pattern
    $builder->build(
        {
            source => 'UserPermission',
            value  => {
                borrowernumber => $librarian->borrowernumber,
                module_bit     => 13,                           # tools module bit
                code           => 'upload_general_files',
            }
        }
    );

    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }     # NO permissions
        }
    );
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $unauth_userid = $patron->userid;

    # Create a test file
    my $file_content = "Test file content for deletion";
    my $filename     = "delete_test.txt";
    my $hashvalue    = 'testhash456';
    my $category     = 'test_delete';

    # Create directory
    my $dir = File::Spec->catdir( $upload_dir, $category );
    mkdir $dir unless -d $dir;

    # Write test file
    my $filepath = File::Spec->catfile( $dir, $hashvalue . '_' . $filename );
    open my $fh, '>', $filepath or die "Cannot write test file: $!";
    print $fh $file_content;
    close $fh;

    # Create database record
    my $uploaded_file = $builder->build_object(
        {
            class => 'Koha::UploadedFiles',
            value => {
                hashvalue          => $hashvalue,
                filename           => $filename,
                dir                => $category,
                filesize           => length($file_content),
                owner              => $librarian->borrowernumber,
                uploadcategorycode => $category,
                public             => 0,
                permanent          => 1
            }
        }
    );

    # Test unauthorized deletion
    $t->delete_ok( "//$unauth_userid:$password@/api/v1/uploaded_files/" . $uploaded_file->id )->status_is(403);

    # Verify file still exists
    ok( -e $filepath,                                    'File still exists after unauthorized delete attempt' );
    ok( Koha::UploadedFiles->find( $uploaded_file->id ), 'Database record still exists' );

    # Test authorized deletion
    $t->delete_ok( "//$userid:$password@/api/v1/uploaded_files/" . $uploaded_file->id )->status_is(204);

    # Verify file and record are deleted
    ok( !-e $filepath,                                    'File deleted from filesystem' );
    ok( !Koha::UploadedFiles->find( $uploaded_file->id ), 'Database record deleted' );

    # Test deletion of non-existent file
    $t->delete_ok( "//$userid:$password@/api/v1/uploaded_files/" . $uploaded_file->id )->status_is(404);

    $schema->storage->txn_rollback;
};
