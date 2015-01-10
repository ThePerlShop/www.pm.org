#!/usr/bin/env perl

# Update perl_mongers.xml from entries in a DNS zone file.

use strict;
use warnings;

use Getopt::Long ();
use XML::LibXML ();

main(\@ARGV);


sub get_options {
    my ($args) = @_;

    my %options = (
        infile => 'perl_mongers.xml',
        outfile => 'perl_mongers-out.xml',
    );

    Getopt::Long::GetOptionsFromArray(
        $args => \%options,
        'infile|i=s',
        'outfile|o=s',
    );

    return \%options;
}


sub read_xml_doc {
    my ($infile) = @_;
    return XML::LibXML->new->parse_file($infile);
}

sub write_xml_doc {
    my ($outfile, $doc) = @_;

    open my $outfh, '>', $outfile
        or die "$0: cannot open '$outfile' for output: $!\n";
    binmode $outfh;
    local $XML::LibXML::setTagCompression = 1;
    $doc->toFH($outfh);
    close $outfh;
}


sub main {
    my ($args) = @_;

    my $options = get_options($args);

    my $doc = read_xml_doc($options->{infile});

    write_xml_doc($options->{outfile}, $doc);
}

