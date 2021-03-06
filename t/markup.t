#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

my %tests = (
    '[quote]Hello, World.[/quote]' => "<div class='bbcode_quote_header'>Quote:<div class='bbcode_quote_body'>Hello, World.</div></div>",
    '[quote=somebody]Hello, World.[/quote]' => "<div class='bbcode_quote_header'>Quote from <a href='/somebody'>somebody</a>:<div class='bbcode_quote_body'>Hello, World.</div></div>",
);

plan tests => int keys(%tests)+1; # TODO: Kill +1 once @mentions are implemented

use DDGC;
my $ddgc = DDGC->new;

my $counter = 0;
for my $bbcode (keys %tests) {
    is $ddgc->markup->html($bbcode), $tests{$bbcode}, "bbcode parse #$counter";

    $counter++;
}


TODO: {
    local $TODO = "Waiting implementation of \@mentions";

    is($ddgc->markup->html('@somebody'), "<a href='/somebody'>\@somebody</a>", '@mention test');
};

done_testing;
