package DDGC;
# ABSTRACT: DuckDuckGo Community Platform

use Moose;

use DDGC::Config;
use DDGC::DB;
use DDGC::User;
use DDGC::DuckPAN;
use DDGC::XMPP;
use DDGC::Comments;
use DDGC::Markup;
use DDGC::Envoy;
use DDGC::Postman;
use DDGC::Forum;
use DDGC::Util::DateTime;

use File::Copy;
use IO::All;
use File::Spec;
use File::ShareDir::ProjectDistDir;
use Net::AIML;
use Text::Xslate qw( mark_raw );
use Class::Load qw( load_class );

##############################################
# TESTING AND DEVELOPMENT, NOT FOR PRODUCTION
sub deploy_fresh {
	my ( $self ) = @_;

	$self->config->rootdir();
	$self->config->filesdir();
	$self->config->cachedir();

	copy($self->config->prosody_db_samplefile,$self->config->rootdir) or die "Copy failed: $!";

	$self->db->connect->deploy;
}
##############################################

####################################################################
#   ____             __ _                       _   _
#  / ___|___  _ __  / _(_) __ _ _   _ _ __ __ _| |_(_) ___  _ __
# | |   / _ \| '_ \| |_| |/ _` | | | | '__/ _` | __| |/ _ \| '_ \
# | |__| (_) | | | |  _| | (_| | |_| | | | (_| | |_| | (_) | | | |
#  \____\___/|_| |_|_| |_|\__, |\__,_|_|  \__,_|\__|_|\___/|_| |_|
#                         |___/

has config => (
	isa => 'DDGC::Config',
	is => 'ro',
	lazy_build => 1,
);
sub _build_config { DDGC::Config->new }
sub is_live { shift->config->is_live }
####################################################################

############################################################
#  ____        _    ____            _
# / ___| _   _| |__/ ___| _   _ ___| |_ ___ _ __ ___  ___
# \___ \| | | | '_ \___ \| | | / __| __/ _ \ '_ ` _ \/ __|
#  ___) | |_| | |_) |__) | |_| \__ \ ||  __/ | | | | \__ \
# |____/ \__,_|_.__/____/ \__, |___/\__\___|_| |_| |_|___/
#                         |___/

# Database (DBIx::Class)
has db => (
	isa => 'DDGC::DB',
	is => 'ro',
	lazy_build => 1,
);
sub _build_db { DDGC::DB->connect(shift) }
sub resultset { shift->db->resultset(@_) }
sub rs { shift->resultset(@_) }

# XMPP access interface
has xmpp => (
	isa => 'DDGC::XMPP',
	is => 'ro',
	lazy_build => 1,
);
sub _build_xmpp { DDGC::XMPP->new({ ddgc => shift }) }

# Markup Text parsing
has markup => (
	isa => 'DDGC::Markup',
	is => 'ro',
	lazy_build => 1,
);
sub _build_markup { DDGC::Markup->new({ ddgc => shift }) }

# Notification System
has envoy => (
	isa => 'DDGC::Envoy',
	is => 'ro',
	lazy_build => 1,
);
sub _build_envoy { DDGC::Envoy->new({ ddgc => shift }) }

# Mail System
has postman => (
	isa => 'DDGC::Postman',
	is => 'ro',
	lazy_build => 1,
	handles => [qw(
		mail
	)],
);
sub _build_postman { DDGC::Postman->new({ ddgc => shift }) }

# Access to the DuckPAN infrastructures (Distribution Management)
has duckpan => (
	isa => 'DDGC::DuckPAN',
	is => 'ro',
	lazy_build => 1,
);
sub _build_duckpan { DDGC::DuckPAN->new({ ddgc => shift }) }

##############################
# __  __    _       _
# \ \/ /___| | __ _| |_ ___
#  \  // __| |/ _` | __/ _ \
#  /  \\__ \ | (_| | ||  __/
# /_/\_\___/_|\__,_|\__\___|
# (Templating SubSystem)
#

has xslate => (
	isa => 'Text::Xslate',
	is => 'ro',
	lazy_build => 1,
);
sub _build_xslate {
	my $self = shift;
	my $xslate;
	$xslate = Text::Xslate->new({
		path => [$self->config->templatedir],
		cache_dir => $self->config->xslate_cachedir,
		suffix => '.tx',
		function => {

			# Functions to access the main model and some functions specific
			d => sub { $self },

			# Mark text as raw HTML
			r => sub { mark_raw(@_) },

			# trick function for DBIx::Class::ResultSet
			results => sub { [ shift->all ] },

			# general functions avoiding xslates problems
			call => sub {
				my $thing = shift;
				my $func = shift;
				$thing->$func;
			},
			call_if => sub {
				my $thing = shift;
				my $func = shift;
				$thing->$func if $thing;
			},
			replace => sub {
				my $source = shift;
				my $from = shift;
				my $to = shift;
				$source =~ s/$from/$to/g;
				return $source;
			},
			urify => sub { lc(join('-',split(/\s+/,join(' ',@_)))) },

			# simple helper for userpage form management
			upf_view => sub { 'userpage/'.$_[1].'/'.$_[0]->view.'.tx' },
			upf_edit => sub { 'my/userpage/field/'.$_[0]->edit.'.tx' },
			#############################################

			# Duration display helper mapped, see DDGC::Util::DateTime
			dur => sub { dur(@_) },
			dur_precise => sub { dur_precise(@_) },
			#############################################

			i => sub {

				my $obj2dir = sub {
					my $obj = shift;
					my $class = ref $obj;
					if ($class =~ m/^DDGC::DB::Result::(.*)$/) {
						my $return = lc($1);
						$return =~ s/::/_/g;
						return $return;
					}
					if ($class =~ m/^DDGC::DB::ResultSet::(.*)$/) {
						my $return = lc($1);
						$return =~ s/::/_/g;
						return $return.'_rs';
					}
					if ($class =~ m/^DDGC::Web::(.*)/) {
						my $return = lc($1);
						$return =~ s/::/_/g;
						return $return;
					}
					die "cant include ".$class." with i-function";
				};

				my $object = shift;
				my $subtemplate = shift;
				my $vars = shift;
				my $main_object;
				my @objects = ( $object );
				if (ref $object eq 'ARRAY') {
					$main_object = $object->[0];
					@objects = @{$object};
				} else {
					$main_object = $object;
				}
				my %current_vars = %{$xslate->current_vars};
				$current_vars{_} = $main_object;
				my @template = ('i');
				my $dir = $obj2dir->($main_object);
				push @template, $dir;
				push @template, $subtemplate ? $subtemplate : 'label';
				my %new_vars;
				for (@objects) {
					my $obj_dir = $obj2dir->($_);
					if (defined $new_vars{$obj_dir}) {
						if (ref $new_vars{$obj_dir} eq 'ARRAY') {
							push @{$new_vars{$obj_dir}}, $_;
						} else {
							$new_vars{$obj_dir} = [
								$new_vars{$obj_dir}, $_,
							];
						}
					} else {
						$new_vars{$obj_dir} = $_;
					}
				}
				for (keys %new_vars) {
					$current_vars{$_} = $new_vars{$_};
				}
				if ($vars) {
					for (keys %{$vars}) {
						$current_vars{$_} = $vars->{$_};
					}
				}
				return mark_raw($xslate->render(join('/',@template).".tx",\%current_vars));
			},

		},
	});
	return $xslate;
}

##############################

##################################################
#  ____       _           ____             _
# |  _ \ ___ | |__   ___ |  _ \ _   _  ___| | __
# | |_) / _ \| '_ \ / _ \| | | | | | |/ __| |/ /
# |  _ < (_) | |_) | (_) | |_| | |_| | (__|   <
# |_| \_\___/|_.__/ \___/|____/ \__,_|\___|_|\_\

has roboduck => (
    isa => 'Net::AIML',
    is => 'ro',
    lazy_build => 1,
);
sub _build_roboduck {
    my ( $self ) = @_;
    Net::AIML->new( botid => $self->config->roboduck_aiml_botid );
}
##################################################

has forum => (
    isa => 'DDGC::Forum',
    is => 'ro',
    lazy_build => 1,
);
sub _build_forum { DDGC::Forum->new( ddgc => shift ) }

#
# ======== User ====================
#

sub update_password {
	my ( $self, $username, $new_password ) = @_;
	return unless $self->config->prosody_running;
	$self->xmpp->admin_data_access->put($username,'accounts',{ password => $new_password });
}

sub delete_user {
	my ( $self, $username ) = @_;
	my $user = $self->db->resultset('User')->single({
		username => $username,
	});
	if ($user) {
		my $deleted_user = $self->db->resultset('User')->single({
			username => $self->config->deleted_account,
		});
		die "Deleted user account doesn't exist!" unless $deleted_user;
		die "You can't delete the deleted account!" if $deleted_user->username eq $user->username;
		my $guard = $self->db->txn_scope_guard;
		if ($self->config->prosody_running) {
			$self->xmpp->_prosody->_db->resultset('Prosody')->search({
				host => $self->config->prosody_userhost,
				user => $username,
			})->delete;
		}
		my @translations = $user->token_language_translations->search({})->all;
		for (@translations) {
			$_->username($deleted_user->username);
			$_->update;
		}
		my @translated_token_languages = $user->token_languages->search({})->all;
		for (@translated_token_languages) {
			$_->translator_users_id($deleted_user->id);
			$_->update;
		}
		my @checked_translations = $user->checked_translations->search({})->all;
		for (@checked_translations) {
			$_->check_users_id($deleted_user->id);
			$_->update;
		}
		my @comments = $user->comments->search({})->all;
		for (@comments) {
			$_->content("This user account has been deleted.");
			$_->users_id($deleted_user->id);
			$_->update;
		}
		$guard->commit;
	}
	return 1;
}

sub create_user {
	my ( $self, $username, $password ) = @_;

	return unless $username and $password;

	unless ($self->config->prosody_running) {
		my $user = $self->find_user($username);
		die "user exists" if $user;
		my $db_user = $self->db->resultset('User')->create({
			username => $username,
			notes => 'Created account',
		});
		return DDGC::User->new({
			username => $username,
			db => $db_user,
			xmpp => {},
			ddgc => $self,
		});
	}

	my %xmpp_user_find = $self->xmpp->user($username);

	die "user exists" if %xmpp_user_find;

	my $prosody_user;
	my $db_user;

	$prosody_user = $self->xmpp->_prosody->_db->resultset('Prosody')->create({
		host => $self->config->prosody_userhost,
		user => $username,
		store => 'accounts',
		key => 'password',
		type => 'string',
		value => $password,
	});

	if ($prosody_user) {

		my $xmpp_data_check;

		$xmpp_data_check = Prosody::Mod::Data::Access->new(
			jid => $username.'@'.$self->config->prosody_userhost,
			password => $password,
		);
		
		if ($xmpp_data_check || !$self->config->prosody_running) {

			$db_user = $self->db->resultset('User')->create({
				username => $username,
				notes => 'Created account',
			});

		} else {

			$self->xmpp->_prosody->_db->resultset('Prosody')->search({
				host => $self->config->prosody_userhost,
				user => $username,
			})->delete;

		}

	}

	return unless $db_user;
	
	my %xmpp_user = $self->xmpp->user($username);
	
	return DDGC::User->new({
		username => $username,
		db => $db_user,
		xmpp => \%xmpp_user,
		ddgc => $self,
	});
}

sub find_user {
	my ( $self, $username ) = @_;

	return unless $username;

	my %xmpp_user;
	my $db_user;

	if ($self->config->prosody_running) {
		%xmpp_user = $self->xmpp->user($username);
		return unless %xmpp_user;
		$db_user = $self->db->resultset('User')->find_or_create({
			username => $username,
			notes => 'Generated automatically based on prosody account',
		});
	} else {
		$db_user = $self->db->resultset('User')->find({
			username => $username,
		});
		return unless $db_user;
	}

	return DDGC::User->new({
		username => $username,
		db => $db_user,
		ddgc => $self,
		xmpp => \%xmpp_user,
	});
}

sub user_counts {
	my ( $self ) = @_;
	my %counts;
	$counts{db} = $self->db->resultset('User')->count;
	$counts{xmpp} = $self->xmpp->_prosody->_db->resultset('Prosody')->search({
		host => $self->config->prosody_userhost,
	},{
		group_by => 'user',
	})->count;
	return \%counts;
}

#
# ======== Comments ====================
#

sub add_comment {
	my ( $self, $context, $context_id, $user, $content, @args ) = @_;
	
	if ( $context eq 'DDGC::DB::Result::Comment' ) {
		my $comment = $self->rs('Comment')->find($context_id);
		return $self->rs('Comment')->create({
			context => $comment->context,
			context_id => $comment->context_id,
			parent_id => $context_id,
			users_id => $user->id,
			content => $content,
			@args,
		});
	} else {
		return $self->rs('Comment')->create({
			context => $context,
			context_id => $context_id,
			users_id => $user->id,
			content => $content,
			@args,
		});
	}
}

sub comments {
	my ( $self, $context, $context_id, @args ) = @_;
	return DDGC::Comments->new(
		context => $context,
		context_id => $context_id,
		ddgc => $self,
		@args,
	);
}

#
# ======== Misc ====================
#

no Moose;
__PACKAGE__->meta->make_immutable;
