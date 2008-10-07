#!perl -T

use strict;
use warnings;
use Test::More;
use WWW::Netflix::API;

my %env = map { $_ => $ENV{"WWW_NETFLIX_API__".uc($_)} } qw/
	consumer_key
	consumer_secret
	access_token
	access_secret
	user_id
/;

if( ! $env{consumer_key} ){
  plan skip_all => 'Make sure that ENV vars are set for consumer_key, etc';
  exit;
}
plan tests => 14;

my $netflix = WWW::Netflix::API->new({
	%env,
	xml_filter => sub { use XML::Simple; XMLin(@_) },
});

sub check_submit {
  my $netflix = shift;
  my $keys = shift;
  my $options = shift || {};
  my $label = sprintf '[%s] ', join('/', @{ $netflix->_levels });
  my $uid = $netflix->user_id;
  $label =~ s/$uid/<UID>/g;
  ok( $netflix->submit(%$options), "$label got data" );
  is( join(',', sort keys %{$netflix->content || {}}), $keys, "$label keys match" );
}


$netflix->REST->Catalog->Titles->Movies('18704531');
check_submit( $netflix, 'average_rating,box_art,category,id,link,release_year,runtime,title' );


$netflix->REST->Users;
check_submit( $netflix, 'can_instant_watch,first_name,last_name,link,preferred_formats,user_id' );

$netflix->REST->Users->At_Home;
check_submit( $netflix, 'at_home_item,number_of_results,results_per_page,start_index,url_template' );

$netflix->REST->Users->Feeds;
check_submit( $netflix, 'link' );

#$netflix->REST->Users->Title_States;
#check_submit( $netflix, 'at_home_item,number_of_results,results_per_page,start_index,url_template', {title_refs=>['http://api.netflix.com/catalog/titles/movies/70036143']} );

$netflix->REST->Users->Queues;
check_submit( $netflix, 'link' );

$netflix->REST->Users->Queues->Disc;
check_submit( $netflix, 'etag,link,number_of_results,queue_item,results_per_page,start_index,url_template' );

$netflix->REST->Users->Queues->Instant;
check_submit( $netflix, 'etag,link,number_of_results,queue_item,results_per_page,start_index,url_template' );

