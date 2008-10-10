#!perl -T

use strict;
use warnings;
use Test::More tests => 87;
use WWW::Netflix::API;
$|=1;

my $netflix = WWW::Netflix::API->new({});

foreach my $k ( qw/
	consumer_key
	consumer_secret
	content_filter
	access_token
	access_secret
	user_id
	content
	original_content
	content_error
	_levels
	rest_url
	_url
	_params
/ ){
  my $label = "[$k]";
  SKIP: {
    ok( $netflix->can($k), "$label can" )
	or skip "'$k' attribute missing", 3;
    is( $netflix->$k(), undef, "$label default" );
    is( $netflix->$k(123), 123, "$label set" );
    is( $netflix->$k, 123, "$label get" );
  };
}

# content
my $fn = sub { uc '='.$_[0].'=' };

is( $netflix->content(123),          123, '[clear content] set content' );
is( $netflix->original_content(123), 123, '[clear content] set original_content' );
is( $netflix->content_error(123),    123, '[clear content] set content_error' );

is( $netflix->content_filter(undef), undef, '[clear content-] unset filter' );
is( $netflix->_set_content(undef),   undef, '[clear content-] clear content' );
is( $netflix->content,               undef, '[clear content-] check content');
is( $netflix->original_content,      undef, '[clear content-] check original_content' );
is( $netflix->content_error,         undef, '[clear content-] check content_error' );

is( $netflix->content_filter($fn),   $fn,   '[clear content+] set filter' );
is( $netflix->_set_content(undef),   undef, '[clear content+] clear content' );
is( $netflix->content,               undef, '[clear content+] check content');
is( $netflix->original_content,      undef, '[clear content+] check original_content' );
is( $netflix->content_error,         undef, '[clear content+] check content_error' );

is( $netflix->content_filter($fn),     $fn,      '[set content+] set filter' );
is( $netflix->_set_content('foo'),     '=FOO=',  '[set content+] set content' );
is( $netflix->content('=FOO='),        '=FOO=',  '[set content+] check content' );
is( $netflix->original_content('foo'), 'foo',    '[set content+] check original_content' );
is( $netflix->content_error(undef),    undef,    '[set content+] check content_error' );

is( $netflix->content_filter(undef),   undef,    '[set content-] unset filter' );
is( $netflix->_set_content('foo'),     'foo',    '[set content-] set content' );
is( $netflix->content('foo'),          'foo',    '[set content-] check content' );
is( $netflix->original_content('foo'), 'foo',    '[set content-] check original_content' );
is( $netflix->content_error(undef),    undef,    '[set content-] check content_error' );


# url
is( $netflix->_url('foo'), 'foo',         '[url;+-] set _url    +'  );
is( $netflix->_levels(undef), undef,      '[url;+-] set _levels -'  );
is( $netflix->url, 'foo',                 '[url;+-] check url()'    );

is( $netflix->_url(''), '',               '[url;--] set _url    -'  );
is( $netflix->_levels(undef), undef,      '[url;--] set _levels -'  );
is( $netflix->url, 'http://api.netflix.com',
                                          '[url;--] check url()'    );

my $arr = [123,456];
is( $netflix->_url('foo'), 'foo',         '[url;++] set _url    +'  );
is_deeply( $netflix->_levels($arr), $arr, '[url;++] set _levels +'  );
is( $netflix->url, 'foo',                 '[url;++] check url()'    );

is( $netflix->_url(''), '',               '[url;-+] set _url    -'  );
is_deeply( $netflix->_levels($arr), $arr, '[url;-+] set _levels +'  );
is( $netflix->url, 'http://api.netflix.com/123/456',
                                          '[url;-+] check url()'    );

