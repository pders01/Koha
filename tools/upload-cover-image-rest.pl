#!/usr/bin/perl

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

=head1 NAME

upload-cover-image-rest.pl - Script for handling cover image uploads using REST API

=head1 SYNOPSIS

upload-cover-image-rest.pl

=head1 DESCRIPTION

This script presents the user with an interface for uploading cover images.
It uses the REST API for file uploads instead of CGI, removing Apache dependency.
Images are processed and stored using the existing Koha::CoverImage infrastructure.

=cut

use Modern::Perl;

use CGI        qw ( -utf8 );
use C4::Auth   qw( get_template_and_user );
use C4::Output qw( output_html_with_http_headers );
use Koha::Biblios;
use Koha::CoverImages;
use Koha::Items;

my $input = CGI->new;

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name => "tools/upload-images-rest.tt",
        query         => $input,
        type          => "intranet",
        flagsrequired => { tools => 'upload_local_cover_images' },
    }
);

my $biblionumber = $input->param('biblionumber');
my $itemnumber   = $input->param('itemnumber');
my $op           = $input->param('op') // q{};

my $biblio;
my $cover_images;
my $item;

if ($itemnumber) {
    $item         = Koha::Items->find($itemnumber);
    $biblionumber = $item->biblionumber;
    $biblio       = Koha::Biblios->find($biblionumber);
    $cover_images = $item->cover_images->as_list;
} elsif ($biblionumber) {
    $biblio       = Koha::Biblios->find($biblionumber);
    $cover_images = $biblio->cover_images->as_list;
}

$template->param(
    biblio       => $biblio,
    biblionumber => $biblionumber,
    itemnumber   => $itemnumber,
    cover_images => $cover_images,
    op           => $op,
);

output_html_with_http_headers $input, $cookie, $template->output;

exit 0;

=head1 AUTHORS

Based on original upload-cover-image.pl by Jared Camins-Esakov of C & P Bibliography Services.
Modified to use REST API instead of CGI uploads.

=cut
