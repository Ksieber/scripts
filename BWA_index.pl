#!/usr/bin/perl
use lib ( '/home/ksieber/scripts/', '/home/ksieber/perl5/lib/perl5/' );
use warnings;
no warnings 'uninitialized';
use strict;
use File::Basename;
use run_cmd;
use mk_dir;
use print_call;
use setup_input;
use File::Basename;

use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
my %options;
my $results = GetOptions( \%options, 'input|i=s', 'input_list|I=s', 'faidx=i', 'output_dir|o=s', 'output_prefix|p=s', 'output_list=s', 'Qsub|q=i', 'help|?', 'sub_name=s', 'sub_mem=s' )
    or die "Unrecognized comand line option. Please try again.\n";

if ( $options{help} ) {
    die "Help: This script will BWA index a fasta file for BWA aligner.
    --input|i=              Single Fasta file to index. May also pass a single .fa file via ARGV.
    --input_list=           Either a list of fasta files or a string of files comma seperated.
    --faidx=                <1|0> [1] 1= samtools faidx index fasta also. Needed for mpileup etc.
    --output_dir|o=         /path/for/output/ [/input/dir/]
    --output_prefix|p=              \$prefix for output names [input_prefix.fasta]
    --output_list=          /path/to/file.list to append ref output names to. 
    --Qsub|q=               1= Submit job to grid.
    --project=              [jdhotopp-lab] 
    --help|?
    \n";
}

if ( $options{Qsub} == 1 ) {
    $options{sub_name} = defined $options{sub_name} ? $options{sub_name} : "Index";
    $options{sub_mem}  = defined $options{sub_mem}  ? $options{sub_mem}  : "6G";
    Qsub_script( \%options );
}

$options{faidx} = $options{faidx} ? $options{faidx} : 1;
if ( !defined $options{input} and !defined $options{input_list} and defined $ARGV[0] and -e "$ARGV[0]" and $ARGV[0] =~ /\.fa(\w){0,3}$/ ) { $options{input} = $ARGV[0]; }
my $inputs = setup_input( \%options );
foreach my $input (@$inputs) {
    my ( $fn, $dir, $suf ) = fileparse( $input, ( '.fa', '.fasta' ) );
    my $output_dir = $options{output_dir} ? $options{output_dir} : $dir;
    $output_dir =~ s/\/$//;
    my $output_prefix = $options{output_prefix} ? $options{output_prefix} : $fn;
    my $bwa_index_prefix = ( ( defined $options{output_prefix} ) or ( defined $options{output_dir} ) ) ? "-p $output_dir/$output_prefix$suf " : undef;

    my $cmd = "bwa index $bwa_index_prefix$input";
    run_cmd($cmd);

    if ( $options{faidx} == 1 ) {
        my $faidx = "samtools faidx $input";
        run_cmd($faidx);
    }

    if ( $options{output_list} ) {
        open( OUT, ">>", "$options{output_list}" ) or die "Error: Unable to open --output_list: $options{output_list}\n";
        print OUT "$output_dir/$output_prefix";
        close OUT;
    }
}

print_complete( \%options );
