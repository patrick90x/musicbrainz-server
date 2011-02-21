package MusicBrainz::Server::Edit::Work::Delete;
use Moose;
use namespace::autoclean;

use MusicBrainz::Server::Constants qw( $EDIT_WORK_DELETE );
use MusicBrainz::Server::Translation qw ( l ln );

extends 'MusicBrainz::Server::Edit::Generic::Delete';
with 'MusicBrainz::Server::Edit::Work::RelatedEntities';

sub edit_name { l('Remove work') }
sub edit_type { $EDIT_WORK_DELETE }
sub _delete_model { 'Work' }
sub work_id { shift->entity_id }

__PACKAGE__->meta->make_immutable;
1;
