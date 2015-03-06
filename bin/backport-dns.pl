#!/usr/bin/env perl

# Update perl_mongers.xml from entries in a DNS zone file.

use strict;
use warnings;

use English;
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
        zonefile => 'dns.txt',
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


sub show_help {
    print <<"END_HELP";
Usage: $0 [options]

Options:
  --help -h  Show this usage message.
  --verbose -v  Display debug or trace messages.
      Multiple -v options increases verbosity.
  --quiet -q  Disable even normal warnings.
  --infile -i  Specify the XML input file (default perl_mongers.xml).
  --outfile -o  Specify the XML output file (default perl_mongers-out.xml).
  --zonefile -z  Specify the DNS zone file (default dns.txt).

END_HELP
}


sub doc_parse_file {
    my ($xml_infile) = @_;
    log_debug("reading XML from '$xml_infile'");
    return XML::LibXML->new->parse_file($xml_infile);
}

sub doc_write_file {
    my ($doc, $xml_outfile) = @_;

    log_debug("writing XML to '$xml_outfile'");
    local $XML::LibXML::setTagCompression = 1;
    $doc->toFile($xml_outfile, 1);
}

sub doc_groups_by_short_name {
    my ($doc) = @_;

    my %groups;         # stores XML group nodes by corresponding short name
    my %group_counts;   # counts how many times a given short name appears in the XML

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


sub group_dns_node {
    my ($group) = @_;

    my $dns_nodes = $group->findnodes('./dns');

    return $dns_nodes->get_node(1) if $dns_nodes->size > 0;

    my $doc = $group->ownerDocument;
    my $dns_node = $doc->createElement('dns');
    $group->appendChild($dns_node);
    return $dns_node;
}


sub groups_parse_dns {
    my ($groups, $zone_infile) = @_;

    log_debug("reading zone data from '$zone_infile'");
    open my $zone_infh, '<', $zone_infile
        or die "$0: cannot open '$zone_infile' for input: $!\n";

    DNS_RR: while (<$zone_infh>) {
        chomp;

        if (! m[^(\S+)\s+(A|CNAME|MX)\s+(.+)$]) {
            log_trace(3, "skipping zone data line $INPUT_LINE_NUMBER");
            next DNS_RR;
        }
        my ($name, $rr_type, $rr_data) = ($1, $2, $3);
        log_trace(3, "found $rr_type RR for $name at line $INPUT_LINE_NUMBER");

        if (! exists $groups->{$name}) {
            log_trace(3, "unknown group $name; skipping");
            next DNS_RR;
        }
        my $group = $groups->{$name};

        my $dns_node = group_dns_node($group);
        my $doc = $dns_node->ownerDocument;

        if ($rr_type eq 'A') {
            my ($ip_address) = split(' ', $rr_data);
            log_trace(2, "adding A for group $name: IP $ip_address");

            my $a_node = $doc->createElement('a');
            $a_node->addChild( $doc->createTextNode($ip_address) );
            $dns_node->appendChild($a_node);

        } elsif ($rr_type eq 'CNAME') {
            my ($cname) = split(' ', $rr_data);
            log_trace(2, "adding CNAME for group $name: host $cname");

            my $cname_node = $doc->createElement('cname');
            $cname_node->addChild( $doc->createTextNode($cname) );
            $dns_node->appendChild($cname_node);

        } elsif ($rr_type eq 'MX') {
            my ($priority, $mx) = split(' ', $rr_data);
            log_trace(2, "adding MX for group $name: priority $priority, host $mx");

            my $mx_node = $doc->createElement('mx');
            $mx_node->addChild( $doc->createAttribute(priority => $priority) );
            $mx_node->addChild( $doc->createTextNode($mx) );
            $dns_node->appendChild($mx_node);

        } else {
            # If the code above is written correctly, this should not happen.
            log_warn("unrecognized RR type: $rr_type");
        }
    }

    close $zone_infh;
}


sub main {
    my ($args) = @_;

    my $options = get_options($args);

    return show_help() if $options->{help};

    if ($options->{quiet}) {
        $verbosity = -1;
    } else {
        $verbosity = ($options->{verbose} // 0);
    }

    my $doc = doc_parse_file($options->{infile});

    my $groups = doc_groups_by_short_name($doc);

    groups_parse_dns($groups, $options->{zonefile});

    doc_write_file($doc, $options->{outfile});
}

