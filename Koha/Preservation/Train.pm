package Koha::Preservation::Train;

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

use JSON qw( to_json );
use Try::Tiny;

use Koha::Database;

use base qw(Koha::Object);

use Koha::Preservation::Processings;
use Koha::Preservation::Train::Items;

use Koha::Exceptions::Preservation;

=head1 NAME

Koha::Preservation::Train - Koha Train Object class

=head1 API

=head2 Class methods

=cut

=head3 default_processing

Return the default processing object for this train

=cut

sub default_processing {
    my ( $self ) = @_;
    my $rs = $self->_result->default_processing;
    return unless $rs;
    return Koha::Preservation::Processing->_new_from_dbic($rs);
}

=head3 add_item

Add item to this train

my $train_item = $train->add_item({item_id => $itemnumber, processing_id => $processing_id});
my $train_item = $train->add_item({barcode => $barcode, processing_id => $processing_id});

=cut

sub add_item {
    my ( $self, $train_item ) = @_;

    my $not_for_loan = C4::Context->preference('PreservationNotForLoanWaitingListIn');

    my $key  = exists $train_item->{item_id} ? 'itemnumber' : 'barcode';
    my $item = Koha::Items->find( { $key => $train_item->{item_id} || $train_item->{barcode} } );
    Koha::Exceptions::Preservation::ItemNotFound->throw unless $item;
    Koha::Exceptions::Preservation::ItemNotInWaitingList->throw if $item->notforloan != $not_for_loan;

    my $train_item_rs = $self->_result->add_to_preservation_trains_items(
        {
            item_id       => $item->itemnumber,
            processing_id => $train_item->{processing_id} || $self->default_processing_id,
            added_on      => \'NOW()',
        }
    );
    $item->notforloan( $self->not_for_loan )->store;
    return Koha::Preservation::Train::Item->_new_from_dbic($train_item_rs);
}

=head3 add_items

my $train_items = $train->add_items([$item_1, $item_2]);

Add items in batch.

=cut

sub add_items {
    my ( $self, $train_items ) = @_;
    my @added_items;
    for my $train_item (@$train_items) {
        try {
            push @added_items, $self->add_item($train_item);
        } catch {

            # FIXME Do we rollback and raise an error or just skip it?
            # FIXME See status code 207 partial success
            warn "Item not added to train: " . $_;
        };
    }
    return Koha::Preservation::Train::Items->search( { train_item_id => [ map { $_->train_item_id } @added_items ] } );
}

=head3 items

my $items = $train->items;

Return the items in this train.

=cut

sub items {
    my ( $self ) = @_;
    my $items_rs = $self->_result->preservation_trains_items;
    return Koha::Preservation::Train::Items->_new_from_dbic($items_rs)
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'PreservationTrain';
}

1;