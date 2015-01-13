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


sub doc_parse_file {
    my ($infile) = @_;
    return XML::LibXML->new->parse_file($infile);
}

sub doc_write_file {
    my ($outfile, $doc) = @_;

    open my $outfh, '>', $outfile
        or die "$0: cannot open '$outfile' for output: $!\n";
    binmode $outfh;
    local $XML::LibXML::setTagCompression = 1;
    $doc->toFH($outfh);
    close $outfh;
}

sub doc_groups_by_short_name {
    my ($doc) = @_;

    my %groups;
    my %group_counts;

    my $group_nodes = $doc->findnodes('/perl_mongers/group');

    NODE: for my $node ($group_nodes->get_nodelist) {
        my $name = $node->find('./name')->get_node(1)->textContent;

        if ($name !~ m/^([^\.]+)\.pm$/) {
            warn "$0: group '$name' does not appear to be a real PM group name; ignoring\n";
            next NODE;
        }

        my $short_name = lc($1);

        my $group_count = ( ++ $group_counts{$short_name} );
        if ($group_count > 1) {
            warn "$0: group '$name' duplicated; ignoring all\n" if $group_count == 2;
            delete $groups{$short_name};
            next NODE;
        }

        $groups{$short_name} = $node;
    }

    return \%groups;
}


sub main {
    my ($args) = @_;

    my $options = get_options($args);

    my $doc = doc_parse_file($options->{infile});

    my $groups = doc_groups_by_short_name($doc);

    doc_write_file($options->{outfile}, $doc);
}

