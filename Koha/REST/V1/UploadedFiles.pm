package Koha::REST::V1::UploadedFiles;

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

use Mojo::Base 'Mojolicious::Controller';

use Try::Tiny qw( catch try );
use File::Temp;
use Digest::MD5;
use File::Spec;
use IO::File;
use Mojo::JSON;

use C4::Context;
use Koha::UploadedFile;
use Koha::UploadedFiles;
use Koha::Uploader;

=head1 API

=head2 Methods

=head3 list

List uploaded files

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $search_params = {};

        # Only filter by public if the parameter is explicitly provided
        if ( defined $c->param('public') ) {
            $search_params->{public} = $c->param('public');
        }

        if ( defined $c->param('category') ) {
            $search_params->{uploadcategorycode} = $c->param('category');
        }

        my $files = Koha::UploadedFiles->search($search_params);

        return $c->render(
            status  => 200,
            openapi => $c->objects->to_api($files)
        );
    } catch {
        return $c->unhandled_exception($_);
    };
}

=head3 get

Get a single uploaded file

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    my $file_id = $c->param('file_id');

    return try {
        my $file = Koha::UploadedFiles->find($file_id);

        return $c->render_resource_not_found("File")
            unless $file;

        # Note: Authorization is handled by OpenAPI framework
        # Public files are accessible to anyone with upload_general_files permission

        my $api_file = $c->objects->to_api($file);

        return $c->render(
            status  => 200,
            openapi => $api_file
        );
    } catch {
        return $c->unhandled_exception($_);
    };
}

=head3 upload

Upload a new file

=cut

sub upload {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $upload = $c->req->upload('file');

        unless ($upload) {
            return $c->render(
                status  => 400,
                openapi => { error => "No file uploaded" }
            );
        }

        # Get current user for owner field
        my $patron = $c->stash('koha.user');

        # Get parameters
        my $public   = $c->param('public') // 0;
        my $temp     = $c->param('temp')   // 0;
        my $category = $c->param('category') || 'koha_upload';

        # If temp, use database name as category
        if ($temp) {
            my $db = C4::Context->config('database');
            $category = 'koha_upload';
            $category =~ s/koha/$db/;
        }

        # Clean filename
        my $filename = $upload->filename;
        $filename =~ s/[^A-Za-z0-9\-\._]//g;

        # Calculate hash
        my $content = $upload->slurp;
        my $md5     = Digest::MD5->new;
        $md5->add($content);
        my $hashvalue = $md5->hexdigest;

        # Check if file already exists
        my $existing = Koha::UploadedFiles->search(
            {
                hashvalue          => $hashvalue,
                uploadcategorycode => $category,
            }
        )->count;

        if ($existing) {
            return $c->render(
                status  => 400,
                openapi => {
                    error      => "File already exists",
                    error_code => 'duplicate_file'
                }
            );
        }

        # Determine directory
        my $dir;
        if ($temp) {
            $dir = File::Spec->catdir( C4::Context->temporary_directory, $category );
        } else {
            $dir = File::Spec->catdir( C4::Context->config('upload_path'), $category );
        }

        # Create directory if needed
        unless ( -d $dir ) {
            mkdir $dir or do {
                return $c->render(
                    status  => 500,
                    openapi => { error => "Could not create upload directory" }
                );
            };
        }

        # Write file
        my $filepath = File::Spec->catfile( $dir, $hashvalue . '_' . $filename );
        my $fh       = IO::File->new( $filepath, "w" );
        unless ($fh) {
            return $c->render(
                status  => 500,
                openapi => { error => "Could not write file" }
            );
        }
        $fh->binmode;
        print $fh $content;
        $fh->close;

        # Create database record
        my $uploaded_file = Koha::UploadedFile->new(
            {
                hashvalue          => $hashvalue,
                filename           => $filename,
                dir                => $category,
                filesize           => length($content),
                owner              => $patron->borrowernumber,
                uploadcategorycode => $category,
                public             => $public,
                permanent          => !$temp,
            }
        )->store;

        # Refresh from database to get the dtcreated timestamp
        $uploaded_file->discard_changes;

        my $api_response = $c->objects->to_api($uploaded_file);

        return $c->render(
            status  => 201,
            openapi => $api_response
        );
    } catch {
        return $c->unhandled_exception($_);
    };
}

=head3 download

Download a file

=cut

sub download {
    my $c = shift->openapi->valid_input or return;

    my $file_id = $c->param('file_id');

    return try {
        my $file = Koha::UploadedFiles->find($file_id);

        return $c->render_resource_not_found("File")
            unless $file;

        # Check permissions
        my $patron = $c->stash('koha.user');
        unless ( $file->public || Koha::Uploader->allows_add_by( $patron->userid ) ) {
            return $c->render(
                status  => 403,
                openapi => { error => "Access forbidden" }
            );
        }

        my $fh = $file->file_handle;
        unless ($fh) {
            return $c->render(
                status  => 404,
                openapi => { error => "File not found on disk" }
            );
        }

        # Get HTTP headers from the file object
        my %http_headers = $file->httpheaders;

        # Set response headers
        my $headers = $c->res->headers;
        $headers->content_type( $http_headers{'-type'} || 'application/octet-stream' );

        # The httpheaders method returns Content-Disposition, but we might want to force download
        if ( $http_headers{'Content-Disposition'} ) {
            $headers->header( 'Content-Disposition' => $http_headers{'Content-Disposition'} );
        } elsif ( $http_headers{'-attachment'} ) {
            $headers->content_disposition( 'attachment; filename="' . $http_headers{'-attachment'} . '"' );
        }

        # Stream the file
        my $content = '';
        while ( my $chunk = <$fh> ) {
            $content .= $chunk;
        }
        $fh->close;

        return $c->render(
            data   => $content,
            status => 200
        );
    } catch {
        return $c->unhandled_exception($_);
    };
}

=head3 delete

Delete an uploaded file

=cut

sub delete {
    my $c = shift->openapi->valid_input or return;

    my $file_id = $c->param('file_id');

    return try {
        my $file = Koha::UploadedFiles->find($file_id);

        return $c->render_resource_not_found("File")
            unless $file;

        $file->delete;

        return $c->render(
            status  => 204,
            openapi => q{}
        );
    } catch {
        return $c->unhandled_exception($_);
    };
}

=head3 download_public

Download a public file without authentication

=cut

sub download_public {
    my $c = shift->openapi->valid_input or return;

    my $file_id = $c->param('file_id');

    return try {
        my $file = Koha::UploadedFiles->find($file_id);

        return $c->render_resource_not_found("File")
            unless $file;

        # Only allow download of public files
        unless ( $file->public ) {
            return $c->render(
                status  => 403,
                openapi => { error => "File is not public" }
            );
        }

        my $fh = $file->file_handle;
        unless ($fh) {
            return $c->render(
                status  => 404,
                openapi => { error => "File not found on disk" }
            );
        }

        # Get HTTP headers from the file object
        my %http_headers = $file->httpheaders();

        # Set response headers
        my $headers = $c->res->headers;
        $headers->content_type( $http_headers{'-type'} || 'application/octet-stream' );

        # The httpheaders method returns Content-Disposition, but we might want to force download
        if ( $http_headers{'Content-Disposition'} ) {
            $headers->header( 'Content-Disposition' => $http_headers{'Content-Disposition'} );
        } elsif ( $http_headers{'-attachment'} ) {
            $headers->content_disposition( 'attachment; filename="' . $http_headers{'-attachment'} . '"' );
        }

        # Stream the file
        my $content = '';
        while ( my $chunk = <$fh> ) {
            $content .= $chunk;
        }
        $fh->close;

        return $c->render(
            data   => $content,
            status => 200
        );
    } catch {
        return $c->unhandled_exception($_);
    };
}

1;
