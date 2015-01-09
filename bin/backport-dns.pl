#!/usr/bin/env perl

# Update perl_mongers.xml from entries in a DNS zone file.

use strict;
use warnings;

use XML::LibXML;

main();


sub main {
    my $xml_infile = 'perl_mongers.xml';
    my $xml_outfile = 'perl_mongers-out.xml';

    my $xml = XML::LibXML->new();
    my $doc = $xml->parse_file($xml_infile);

    open my $xml_outfh, '>', $xml_outfile
        or die "$0: cannot open '$xml_outfile' for output: $!\n";
    binmode $xml_outfh;
    $doc->toFH($xml_outfh);
    close $xml_outfh;
}

