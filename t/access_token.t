#!perl

use strict;
use warnings;
use Test::More;
use WWW::Netflix::API;

my %env = map { $_ => $ENV{"WWW_NETFLIX_API__".uc($_)} } qw/
	consumer_key
	consumer_secret
	login_user
	login_pass
/;

if( ! $env{consumer_key} ){
  plan skip_all => 'Make sure that ENV vars are set for consumer_key, etc';
  exit;
}
plan tests => 3;

my $netflix = WWW::Netflix::API->new({
	consumer_key => $env{consumer_key},
	consumer_secret => $env{consumer_secret},
});

my $user = $env{login_user};
my $pass = $env{login_pass};

my ($access_token, $access_secret, $user_id) = $netflix->RequestAccess( $user, $pass );

ok( $access_token,  "got access_token: " . $access_token );
ok( $access_secret, "got access_secret" );
ok( $user_id,       "got user_id: " . $user_id );

