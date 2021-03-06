package DDGC::DB::Base::Result;
# ABSTRACT: Base class for all DBIx::Class Result base classes of the project

use Moose;
use MooseX::NonMoose;
extends 'DBIx::Class::Core';
use namespace::autoclean;

__PACKAGE__->load_components(qw/
    TimeStamp
    InflateColumn::DateTime
    InflateColumn::Serializer
    EncodedColumn
/);

sub default_result_namespace { 'DDGC::DB::Result' }

sub ddgc { shift->result_source->schema->ddgc }
sub schema { shift->schema }

sub add_event {
	my ( $self, $action, %args ) = @_;
	my %event;
	$event{context} = ref $self;
	$event{context_id} = $self->id;
	my $users_id;
	if ($self->can('users_id')) {
		$users_id = $self->users_id;
	} elsif ($self->can('user')) {
		$users_id = $self->user->id
	}
	$users_id = delete $args{users_id} if defined $args{users_id};
	if ($users_id) {
		$event{users_id} = $users_id;
	}
	$event{action} = $action;
	if ($self->can('event_related')) {
		$event{related} = [$self->event_related, defined $args{related} ? @{delete $args{related}} : ()];
	}
	$event{data} = \%args if %args;
	$self->result_source->schema->resultset('Event')->create({ %event });
}

sub has_context {
	my ( $self ) = @_;
	return $self->does('DDGC::DB::Role::HasContext');
}

sub belongs_to {
	my ($self, @args) = @_;

	$args[3] = {
		is_foreign => 1,
		on_update => 'cascade',
		on_delete => 'restrict',
		%{$args[3]||{}}
	};

	$self->next::method(@args);
}

use overload '""' => sub {
	my $self = shift;
	return (ref $self).' #'.$self->id;
}, fallback => 1;

no Moose;
__PACKAGE__->meta->make_immutable;
