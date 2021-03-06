package DDGC::Config;
# ABSTRACT: DDGC main configuration file 

use strict;
use warnings;

use File::Path qw( make_path );
use File::Spec;
use File::ShareDir::ProjectDistDir;
use Path::Class;
use Catalyst::Utils;

use namespace::autoclean;

sub new { bless {}, shift }

sub nid { defined $ENV{'DDGC_NID'} ? $ENV{'DDGC_NID'} : 1 }
sub pid { defined $ENV{'DDGC_PID'} ? $ENV{'DDGC_PID'} : $$ }

sub rootdir_path {
	my $dir = defined $ENV{'DDGC_ROOTDIR'} ? $ENV{'DDGC_ROOTDIR'} : $ENV{HOME}.'/ddgc/';
	return $dir;
}

sub rootdir {
	my $dir = rootdir_path;
	make_path($dir) if !-d $dir;
	return File::Spec->rel2abs( $dir );
}

sub web_base { defined $ENV{'DDGC_WEB_BASE'} ? $ENV{'DDGC_WEB_BASE'} : 'https://dukgo.com' }

sub prosody_db_samplefile { File::Spec->rel2abs( File::Spec->catfile( dist_dir('DDGC'), 'ddgc.prosody.sqlite' ) ) }

sub duckpan_cdh_template { File::Spec->rel2abs( File::Spec->catfile( dist_dir('DDGC'), 'perldoc', 'duckpan.html' ) ) }
sub duckpan_cdh_assets {{
	'duckpan.css' => File::Spec->rel2abs( File::Spec->catfile( dist_dir('DDGC'), 'perldoc', 'duckpan.css' ) ),
	'duckpan.png' => File::Spec->rel2abs( File::Spec->catfile( dist_dir('DDGC'), 'perldoc', 'duckpan.png' ) ),
}}

sub prosody_db_driver { defined $ENV{'DDGC_PROSODY_DB_DRIVER'} ? $ENV{'DDGC_PROSODY_DB_DRIVER'} : 'SQLite3' }
sub prosody_db_database { defined $ENV{'DDGC_PROSODY_DB_DATABASE'} ? $ENV{'DDGC_PROSODY_DB_DATABASE'} : rootdir().'/ddgc.prosody.sqlite' }

sub prosody_db_username { $ENV{'DDGC_PROSODY_DB_USERNAME'} if defined $ENV{'DDGC_PROSODY_DB_USERNAME'} }
sub prosody_db_password { $ENV{'DDGC_PROSODY_DB_PASSWORD'} if defined $ENV{'DDGC_PROSODY_DB_PASSWORD'} }
sub prosody_db_host { $ENV{'DDGC_PROSODY_DB_HOST'} if defined $ENV{'DDGC_PROSODY_DB_HOST'} }

sub prosody_userhost { defined $ENV{'DDGC_PROSODY_USERHOST'} ? $ENV{'DDGC_PROSODY_USERHOST'} : 'test.domain' }

sub is_live { prosody_userhost() eq 'dukgo.com' ? 1 : 0 }

sub prosody_admin_username { defined $ENV{'DDGC_PROSODY_ADMIN_USERNAME'} ? $ENV{'DDGC_PROSODY_ADMIN_USERNAME'} : 'testone' }
sub prosody_admin_password { defined $ENV{'DDGC_PROSODY_ADMIN_PASSWORD'} ? $ENV{'DDGC_PROSODY_ADMIN_PASSWORD'} : 'testpass' }

sub mail_test { defined $ENV{'DDGC_MAIL_TEST'} ? $ENV{'DDGC_MAIL_TEST'} : 0 }
sub mail_test_log { defined $ENV{'DDGC_MAIL_TEST_LOG'} ? $ENV{'DDGC_MAIL_TEST_LOG'} : '' }
sub smtp_host { $ENV{'DDGC_SMTP_HOST'} if defined $ENV{'DDGC_SMTP_HOST'} }
sub smtp_ssl { defined $ENV{'DDGC_SMTP_SSL'} ? $ENV{'DDGC_SMTP_SSL'} : 0 }
sub smtp_sasl_username { $ENV{'DDGC_SMTP_SASL_USERNAME'} if defined $ENV{'DDGC_SMTP_SASL_USERNAME'} }
sub smtp_sasl_password { $ENV{'DDGC_SMTP_SASL_PASSWORD'} if defined $ENV{'DDGC_SMTP_SASL_PASSWORD'} }

sub blog_posts_dir { defined $ENV{'DDGC_BLOG_POSTS_DIR'} ? $ENV{'DDGC_BLOG_POSTS_DIR'} : dist_dir('DDGC').'/blog' }
sub templatedir { defined $ENV{'DDGC_TEMPLATEDIR'} ? $ENV{'DDGC_TEMPLATEDIR'} : dir( Catalyst::Utils::home('DDGC'), 'templates' )->resolve->absolute->stringify }

sub duckpan_url { defined $ENV{'DDGC_DUCKPAN_URL'} ? $ENV{'DDGC_DUCKPAN_URL'} : 'http://duckpan.org/' }

sub duckpan_locale_uploader { defined $ENV{'DDGC_DUCKPAN_LOCALE_UPLOADER'} ? $ENV{'DDGC_DUCKPAN_LOCALE_UPLOADER'} : 'testone' }

sub roboduck_aiml_botid { defined $ENV{'ROBODUCK_AIML_BOTID'} ? $ENV{'ROBODUCK_AIML_BOTID'} : 'ab83497d9e345b6b' }

sub deleted_account { defined $ENV{'DDGC_DELETED_ACCOUNT'} ? $ENV{'DDGC_DELETED_ACCOUNT'} : 'testone' }

# DANGER: DEACTIVATES PASSWORD CHECK FOR ALL USERACCOUNTS!!!!!!!!!!!!!!!!!!!!!!
sub prosody_running { defined $ENV{'DDGC_PROSODY_RUNNING'} ? $ENV{'DDGC_PROSODY_RUNNING'} : 0 }
sub fallback_user { 'testtwo' }

sub prosody_connect_info {
	my %params = (
		quote_char              => '"',
		name_sep                => '.',
	);
	my $driver;
	if (prosody_db_driver eq 'SQLite3') {
		$params{sqlite_unicode} = 1;
		$driver = 'SQLite';
	} elsif (prosody_db_driver eq 'MySQL') {
		$params{mysql_enable_utf8} = 1;
		$driver = 'mysql';
	} elsif (prosody_db_driver eq 'PostgreSQL') {
		$params{pg_enable_utf8} = 1;
		$driver = 'Pg';
	}
	my $dsn = 'dbi:'.$driver.':dbname='.prosody_db_database.( prosody_db_host() ? ';host='.prosody_db_host : '' );
	return [
		$dsn,
		prosody_db_username,
		prosody_db_password,
		\%params,
	];
}

sub db_dsn { defined $ENV{'DDGC_DB_DSN'} ? $ENV{'DDGC_DB_DSN'} : 'dbi:SQLite:'.rootdir().'/ddgc.db.sqlite' }
sub db_user { defined $ENV{'DDGC_DB_USER'} ? $ENV{'DDGC_DB_USER'} : '' }
sub db_password { defined $ENV{'DDGC_DB_PASSWORD'} ? $ENV{'DDGC_DB_PASSWORD'} : '' }

sub db_params {
	my %vars = (
		quote_char		=> '"',
		name_sep		=> '.',
	);
	if (db_dsn =~ m/:SQLite:/) {
		$vars{sqlite_unicode} = 1;
		$vars{on_connect_do} = 'PRAGMA SYNCHRONOUS = OFF';
	} elsif (db_dsn =~ m/:Pg:/) {
		$vars{pg_enable_utf8} = 1;
	}
	return \%vars;
}

sub duckpandir {
	my $dir = defined $ENV{'DDGC_DUCKPANDIR'} ? $ENV{'DDGC_DUCKPANDIR'} : rootdir().'/duckpan/';
	make_path($dir) if !-d $dir;
	return File::Spec->rel2abs( $dir );
}

sub filesdir {
	my $dir = defined $ENV{'DDGC_FILESDIR'} ? $ENV{'DDGC_FILESDIR'} : rootdir().'/files/';
	make_path($dir) if !-d $dir;
	return File::Spec->rel2abs( $dir );
}

sub screen_filesdir {
	my $dir = defined $ENV{'DDGC_FILESDIR_SCREEN'} ? $ENV{'DDGC_FILESDIR_SCREEN'} : filesdir().'/screens/';
	make_path($dir) if !-d $dir;
	return File::Spec->rel2abs( $dir );
}

sub cachedir {
	my $dir = defined $ENV{'DDGC_CACHEDIR'} ? $ENV{'DDGC_CACHEDIR'} : rootdir().'/cache/';
	make_path($dir) if !-d $dir;
	return File::Spec->rel2abs( $dir );
}

sub xslate_cachedir {
	my $dir = defined $ENV{'DDGC_CACHEDIR_XSLATE'} ? $ENV{'DDGC_CACHEDIR_XSLATE'} : cachedir().'/xslate/';
	make_path($dir) if !-d $dir;
	return File::Spec->rel2abs( $dir );
}

1;