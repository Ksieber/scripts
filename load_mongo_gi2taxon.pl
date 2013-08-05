#!/usr/bin/perl

=head1 NAME

load_mongo_gi2taxon.pl

=head1 SYNOPSIS

Loads mongo gi2taxon on a remote host

=head1 DESCRIPTION

Use this script to start/load a gi2taxon database. It assumes you have started 
a mongod server on the remote host

=head1 AUTHOR - Karsten Sieber

e-mail: ksieber@som.umaryland.edu

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

use strict;
use lib '/local/projects-t3/HLGT/scripts/lgtseek/lib/';
use LGTSeek;
use File::Basename;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
my %options;
my $results = GetOptions (\%options,
                          'dbhost=s', # Comma separated list of files
                          'taxon_dir=s',
                          'port=s',
                          'taxon_idx_dir=s',
                          );

my $port=$options{port} ? $options{port} : 10001;

# Create an lgtseek object
my $lgtseek = LGTSeek->new({
    taxon_dir => $options{taxon_dir},
    taxon_host => $options{dbhost}.":$port",
    chunk_size => '500000',
    taxon_idx_dir => $options{taxon_idx_dir}, 
});

my $gi2tax = $lgtseek->getGiTaxon();
# OK, hopefully that worked.