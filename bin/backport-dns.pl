#!/usr/bin/env perl

# Update perl_mongers.xml from entries in a DNS zone file.

use strict;
use warnings;

use Getopt::Long ();
use XML::LibXML ();

main(\@ARGV);


# MUST initialize $verbosity in &main:
#   -1 == quiet: no warnings no output
#   0 == normal: warnings only
#   1 == verbose: warnings and high-level flow
#   2 or greater == trace: increasing levels of verbosity
my $verbosity;

sub log_trace {
    my $level = shift;
    print STDERR ("$0: ", @_, "\n") if $verbosity >= $level;
}

sub log_debug {
    print STDERR ("$0: ", @_, "\n") if $verbosity >= 1;
}

sub log_warn {
    warn("$0: ", @_, "\n") if $verbosity >= 0;
}


sub get_options {
    my ($args) = @_;

    my %options = (
        infile => 'perl_mongers.xml',
        outfile => 'perl_mongers-out.xml',
    );

    Getopt::Long::GetOptionsFromArray(
        $args => \%options,
        'help|h',
        'verbose|v+',
        'quiet|q',
        'infile|i=s',
        'outfile|o=s',
        'zonefile|z=s',
    );

    return \%options;
}


sub doc_parse_file {
    my ($infile) = @_;
    log_debug("reading XML from '$infile'");
    return XML::LibXML->new->parse_file($infile);
}

sub doc_write_file {
    my ($outfile, $doc) = @_;

    log_debug("writing XML to '$outfile'");
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

    log_debug("finding groups in XML");
    my $group_nodes = $doc->findnodes('/perl_mongers/group');

    NODE: for my $node ($group_nodes->get_nodelist) {
        my $name = $node->find('./name')->get_node(1)->textContent;
        log_trace(2, "found group '$name'");

        if ($name !~ m/^([^\.]+)\.pm$/) {
            log_warn("group '$name' does not appear to be a real PM group name; ignoring");
            next NODE;
        }

        my $short_name = lc($1);
        log_trace(3, "parsed short name '$short_name'");

        my $group_count = ( ++ $group_counts{$short_name} );
        log_trace(3, "group seen $group_counts{$short_name} times");
        if ($group_count > 1) {
            log_warn("group '$name' duplicated; ignoring all") if $group_count == 2;
            delete $groups{$short_name};
            next NODE;
        }

        log_trace(3, "recording group '$name' as '$short_name'");
        $groups{$short_name} = $node;
    }

    return \%groups;
}


sub main {
    my ($args) = @_;

    my $options = get_options($args);

    # return show_help() if $options->{help};

    if ($options->{quiet}) {
        $verbosity = -1;
    } else {
        $verbosity = ($options->{verbose} // 0);
    }

    my $doc = doc_parse_file($options->{infile});

    my $groups = doc_groups_by_short_name($doc);

    doc_write_file($options->{outfile}, $doc);
}

