#!/usr/bin/perl

use strict;
use warnings;
use WWW::Netflix::API;

my $netflix = WWW::Netflix::API->new({
	do('vars.inc'),
});

# NOTE -- There's a much smaller limit (~20x/day) on this request.
# But note that Netflix only updates the catalog daily.
# The catalog is ~200MB of POX.

$netflix->REST->Catalog->Titles->Index;
$netflix->Get();

open FILE, '>', 'catalog.xml';
print FILE ${$netflix->content_ref};
close FILE;

