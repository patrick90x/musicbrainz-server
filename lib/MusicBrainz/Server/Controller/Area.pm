package MusicBrainz::Server::Controller::Area;
use Moose;

BEGIN { extends 'MusicBrainz::Server::Controller'; }

with 'MusicBrainz::Server::Controller::Role::Load' => {
    model           => 'Area',
    relationships   => { all => ['show'], cardinal => ['edit'], default => ['url'] },
};
with 'MusicBrainz::Server::Controller::Role::LoadWithRowID';
with 'MusicBrainz::Server::Controller::Role::Annotation';
with 'MusicBrainz::Server::Controller::Role::Alias';
with 'MusicBrainz::Server::Controller::Role::Details';
with 'MusicBrainz::Server::Controller::Role::Tag';
with 'MusicBrainz::Server::Controller::Role::EditListing';
with 'MusicBrainz::Server::Controller::Role::WikipediaExtract';
with 'MusicBrainz::Server::Controller::Role::EditRelationships';
with 'MusicBrainz::Server::Controller::Role::JSONLD' => {
    endpoints => {show => {}, aliases => {copy_stash => ['aliases']}}
};
with 'MusicBrainz::Server::Controller::Role::Collection' => {
    entity_type => 'area'
};

use Data::Page;
use HTTP::Status qw( :constants );
use MusicBrainz::Server::Translation qw( l );
use MusicBrainz::Server::Constants qw( $EDIT_AREA_CREATE $EDIT_AREA_EDIT $EDIT_AREA_DELETE $EDIT_AREA_MERGE );
use Sql;

=head1 NAME

MusicBrainz::Server::Controller::Area - Catalyst Controller for working
with Area entities

=head1 DESCRIPTION

The area controller is used for interacting with
L<MusicBrainz::Server::Area> entities - both read and write. It provides
views to the area data itself, and a means to navigate to a release
that is attributed to a certain area.

=head1 ACTIONS

=head2 READ ONLY PAGES

The follow pages can are all read only.

=head2 base

Base action to specify that all actions live in the C<area>
namespace

=cut

sub base : Chained('/') PathPart('area') CaptureArgs(0) { }

=head2 area

Extends loading by fetching any extra data required in the area header.

=cut

after 'load' => sub {
    my ($self, $c) = @_;

    my $area = $c->stash->{area};

    $c->model('AreaType')->load($area);
    $c->model('Area')->load_containment($area);
};

=head2 show

Shows an area's main landing page.

=cut

sub show : PathPart('') Chained('load')
{
    my ($self, $c) = @_;

    $c->stash(template => 'area/index.tt');
}

=head2 artists

Shows artists for an area.

=cut

sub artists : Chained('load')
{
    my ($self, $c) = @_;
    my $artists = $self->_load_paged($c, sub {
        $c->model('Artist')->find_by_area($c->stash->{area}->id, shift, shift);
    });
        $c->model('ArtistType')->load(@$artists);
        $c->model('Gender')->load(@$artists);
    if ($c->user_exists) {
        $c->model('Artist')->rating->load_user_ratings($c->user->id, @$artists);
    }
    $c->stash( artists => $artists );
}

=head2 labels

Shows labels for an area.

=cut

sub labels : Chained('load')
{
    my ($self, $c) = @_;
    my $labels = $self->_load_paged($c, sub {
        $c->model('Label')->find_by_area($c->stash->{area}->id, shift, shift);
    });
    $c->model('LabelType')->load(@$labels);
    if ($c->user_exists) {
        $c->model('Label')->rating->load_user_ratings($c->user->id, @$labels);
    }
    $c->stash( labels => $labels );
}

=head2 releases

Shows releases for an area

=cut

sub releases : Chained('load')
{
    my  ($self, $c) = @_;

    my $releases = $self->_load_paged($c, sub {
            $c->model('Release')->find_by_country($c->stash->{area}->id, shift, shift);
        });

    $c->model('ArtistCredit')->load(@$releases);
    $c->model('Release')->load_related_info(@$releases);
    $c->stash(
        template => 'area/releases.tt',
        releases => $releases,
    );
}

=head2 places

Shows places for an area.

=cut

sub places : Chained('load')
{
    my ($self, $c) = @_;
    my $places = $self->_load_paged($c, sub {
        $c->model('Place')->find_by_area($c->stash->{area}->id, shift, shift);
    });
    $c->model('PlaceType')->load(@$places);
    $c->stash( places => $places );
}

after [qw( show collections details tags aliases artists labels releases places )] => sub {
    my ($self, $c) = @_;
    $self->_stash_collections($c);
};

=head2 users

Shows editors located in this area.

=cut

sub users : Chained('load') {
    my ($self, $c) = @_;
    my $editors = $self->_load_paged($c, sub {
        my ($editors, $total) = $c->model('Editor')->find_by_area($c->stash->{area}->id, shift, shift);
        $c->model('Editor')->load_preferences(@$editors);
        ($editors, $total);
    });
    $c->stash( editors => $editors );
}

=head2 WRITE METHODS

=cut

with 'MusicBrainz::Server::Controller::Role::Create' => {
    form      => 'Area',
    edit_type => $EDIT_AREA_CREATE,
};

with 'MusicBrainz::Server::Controller::Role::Edit' => {
    form           => 'Area',
    edit_type      => $EDIT_AREA_EDIT,
};

with 'MusicBrainz::Server::Controller::Role::Merge' => {
    edit_type => $EDIT_AREA_MERGE,
};

with 'MusicBrainz::Server::Controller::Role::Delete' => {
    edit_type      => $EDIT_AREA_DELETE,
};

for my $method (qw( create edit merge merge_queue delete add_alias edit_alias delete_alias edit_annotation )) {
    before $method => sub {
        my ($self, $c) = @_;
        if (!$c->user->is_location_editor) {
            $c->detach('/error_403');
        }
    };
};

sub _merge_load_entities
{
    my ($self, $c, @areas) = @_;
    $c->model('Area')->load_containment(@areas);
};

=head1 LICENSE

This software is provided "as is", without warranty of any kind, express or
implied, including  but not limited  to the warranties of  merchantability,
fitness for a particular purpose and noninfringement. In no event shall the
authors or  copyright  holders be  liable for any claim,  damages or  other
liability, whether  in an  action of  contract, tort  or otherwise, arising
from,  out of  or in  connection with  the software or  the  use  or  other
dealings in the software.

GPL - The GNU General Public License    http://www.gnu.org/licenses/gpl.txt
Permits anyone the right to use and modify the software without limitations
as long as proper  credits are given  and the original  and modified source
code are included. Requires  that the final product, software derivate from
the original  source or any  software  utilizing a GPL  component, such  as
this, is also licensed under the GPL license.

=cut

1;
