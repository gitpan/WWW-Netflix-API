package WWW::Netflix::API;

use warnings;
use strict;

our $VERSION = '0.01';

use base qw(Class::Accessor);

use Net::OAuth;
use LWP::Simple();
use HTTP::Request::Common;
use LWP::UserAgent;
use WWW::Mechanize;
use URI::Escape;

__PACKAGE__->mk_accessors(qw/
	consumer_key
	consumer_secret
	xml_filter
	access_token
	access_secret
	user_id
	_content
	_levels
	rest_url
/);

sub REST {
  my $self = shift;
  $self->_levels([]);
  $self->_content(undef);
  return WWW::Netflix::API::_UrlAppender->new( stack => $self->_levels, append => {users=>$self->user_id} );
}

sub url {
  my $self = shift;
  return join '/', 'http://api.netflix.com', @{ $self->_levels || [] };
}

sub submit {
  my $self = shift;
  my %options = (@_);
  my $request = Net::OAuth->request("protected resource")->new(
	consumer_key => $self->consumer_key,
	consumer_secret => $self->consumer_secret,

        request_url => $self->url,

	token => $self->access_token,
	token_secret => $self->access_secret,
	request_method => 'GET',
	signature_method => 'HMAC-SHA1',
	timestamp => time,
	nonce => join('::', $0, $$),
	version => '1.0',
	extra_params => \%options,
  );
  $request->sign;
  $self->rest_url( $request->to_url->as_string );
  $self->_content( LWP::Simple::get( $self->rest_url ) );
  return 1;
}

sub content {
  my $self = shift;
  return $self->_content && $self->xml_filter
	? &{$self->xml_filter}($self->_content)
	: $self->_content
  ;
}

sub rest2sugar {
  my $self = shift;
  my $url = shift;
  my @stack = ( '$netflix', 'REST' );
  my @params;
  $url =~ s#^http://api.netflix.com##;
  $url =~ s#(/users/)(\w|-){30,}/#$1#i;
  $url =~ s#/(\d+)(?=/|$)#('$1')#;
  if( $url =~ s#\?(.+)## ){
    my $querystring = $1;
    @params = map {
	  my ($k,$v) = split /=/, $_, 2;
	  [ $k, uri_unescape($v) ]
	}
	split /&/, $querystring;
  }
  push @stack, map {
		join '_', map { ucfirst } split '_', lc $_
	}
	grep { length($_) }
	split '/', $url
  ;
  return (
	join('->', @stack),
	sprintf('$netflix->submit(%s)',
		join( ', ', map { sprintf "'%s' => '%s'", @$_ } @params ),
	),
  );
	
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub __get_token_response {
  my $self = shift;
  my $which = shift;
  my $token = shift;
  my $secret = shift;
  my %urls = qw(
	request	http://api.netflix.com/oauth/request_token
	access	http://api.netflix.com/oauth/access_token
  );
  my $request = Net::OAuth->request("$which token")->new(
	consumer_key => $self->consumer_key,
	consumer_secret => $self->consumer_secret,
	($token ? ( token => $token,
	token_secret => $secret, ) : () ),
	request_url => $urls{$which},
	request_method => 'POST',
	signature_method => 'HMAC-SHA1',
	timestamp => time,
	nonce => join('::', $0, $$),
	version => '1.0',
  );

  $request->sign;

  my $ua = LWP::UserAgent->new;
  my $res = $ua->request(POST $request->to_url); # Post message to the Service Provider

  if (! $res->is_success) {
	warn sprintf 'Request for %s token failed (%s): "%s"', $which, $res->status_line, $res->content;
	return;
  }

  my $response = Net::OAuth->response("$which token")->from_post_body($res->content);
  return $response;
}
sub __get_request_token {
  my $self = shift;
  my $response = $self->__get_token_response('request');
  return (
	$response->token,
	$response->token_secret,
	$response->extra_params->{login_url},
	$response->extra_params->{application_name},
  );
}
sub __get_access_token {
  my $self = shift;
  my $response = $self->__get_token_response('access', @_);
  return (
	$response->token,
	$response->token_secret,
	$response->extra_params->{user_id},
  );
}

sub RequestAccess {
  my $self = shift;
  my ($user, $pass) = @_;

  my ($request_token, $request_secret, $login_url, $application_name) = $self->__get_request_token;

    my $mech = WWW::Mechanize->new;
    my $url = sprintf '%s&oauth_callback=%s&oauth_consumer_key=%s&application_name=%s',
	$login_url,
	map { uri_escape($_) }
		'',
		$self->consumer_key,
		$application_name,
    ; 
    $mech->get($url);
    $mech->submit_form(
	form_number => 1,
	fields => {
		login => $user,
		password => $pass,
	},
    );
  return unless $mech->content =~ /successfully/i && $mech->content !~ /failed/i;

  my ($access_token, $access_secret, $user_id) = $self->__get_access_token( $request_token, $request_secret );

  $self->access_token(   $access_token  );
  $self->access_secret(  $access_secret );
  $self->user_id(        $user_id       );
  return ($self->access_token, $self->access_secret, $self->user_id);
}


########################################

package WWW::Netflix::API::_UrlAppender;

use strict;
use warnings;
our $AUTOLOAD;

sub new {
  my $self = shift;
  my $params = { @_ };
  return bless { stack => $params->{stack}, append => $params->{append}||{} }, $self;
}

sub AUTOLOAD {
  my $self = shift;
  my $dir = lc $AUTOLOAD;
  $dir =~ s/.*:://; 
  if( $dir ne 'destroy' ){
    push @{ $self->{stack} }, $dir;
    push @{ $self->{stack} }, @_ if scalar @_;
    push @{ $self->{stack} }, $self->{append}->{$dir} if exists $self->{append}->{$dir};
  }
  return $self;
}

1; # End of WWW::Netflix::API

__END__

=pod

=head1 NAME

WWW::Netflix::API - Interface for Netflix's API

=head1 VERSION

Version 0.01

=head1 OVERVIEW

This module is to provide your perl applications with easy access to the L<Netflix API|http://developer.netflix.com/>.  The Netflix API allows access to movie and user information, including queues, rating, rental history, and more.

=head1 SYNOPSIS

  use WWW::Netflix::API;
  use Data::Dumper;

  my %auth = Your::Custom::getAuthFromCache();
  # consumer key/secret values below are fake
  my $netflix = WWW::Netflix::API->new({
        consumer_key    => '4958gj86hj6g99',
        consumer_secret => 'QWEas1zxcv',
	access_token    => $auth{access_token},
	access_secret   => $auth{access_secret},
	user_id         => $auth{user_id},

	xml_filter => sub { use XML::Simple; XMLin(@_) },  # optional
  });
  if( ! $auth{user_id} ){
    my ( $user, $pass ) = .... ;
    @auth{qw/access_token access_secret user_id/} = $netflix->RequestAccess( $user, $pass );
    Your::Custom::storeAuthInCache( %auth );
  }

  $netflix->REST->Users->Feeds;
  $netflix->submit() or die 'request failed';
  print Dumper $netflix->content;

  $netflix->REST->Catalog->Titles->Movies('18704531');
  $netflix->submit() or die 'request failed';
  print Dumper $netflix->content;

=head1 GETTING STARTED

The first step to using this module is to register at L<http://developer.netflix.com> -- you will need to register your application, for which you'll receive a consumer_key and consumer_secret keypair.

Any applications written with the Netflix API must adhere to the
L<Terms of Use|http://developer.netflix.com/page/Api_terms_of_use>
and
L<Branding Requirements|http://developer.netflix.com/docs/Branding>.

This module provides access to the REST API via perl syntactical sugar. For example, to find a user's queue, the REST url is of the form users/I<userID>/feeds :

  http://api.netflix.com/users/T1tareQFowlmc8aiTEXBcQ5aed9h_Z8zdmSX1SnrKoOCA-/queues/disc

Using this module, the syntax would be:

  $netflix->REST->Users->Feeds;
  $netflix->submit(%$params) or die;
  print $netflix->content;

Other examples include:

  $netflix->REST->Users;
  $netflix->REST->Users->At_Home;
  $netflix->REST->Catalog->Titles->Movies('18704531');
  $netflix->REST->Users->Feeds;
  $netflix->REST->Users->Rental_History;

All of the possibilities (and parameter details) are outlined here:
L<http://developer.netflix.com/docs/REST_API_Reference>

There is a helper method L<rest2sugar> included that will provide the proper syntax given a url.  This is handy for translating the example urls in the REST API Reference.


The following describe the authentication that's happening under the hood and were used heavily in writing this module:

L<http://developer.netflix.com/docs/Security>

L<http://josephsmarr.com/2008/10/01/using-netflixs-new-api-a-step-by-step-guide/#>

L<Net::OAuth>

=head1 METHODS 

=head2 new

=head2 REST

=head2 RequestAccess

=head2 submit

=head1 ATTRIBUTES

=head2 content

=head2 url

=head2 rest2sugar

=head2  .....other attributes.....

=head1 INTERNAL

=head1 AUTHOR

David Westbrook, C<< <dwestbrook at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-www-netflix-api at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-Netflix-API>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::Netflix::API


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-Netflix-API>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WWW-Netflix-API>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/WWW-Netflix-API>

=item * Search CPAN

L<http://search.cpan.org/dist/WWW-Netflix-API>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2008 David Westbrook, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

