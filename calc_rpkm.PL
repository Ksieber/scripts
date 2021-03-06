#!/usr/bin/perl

my $VERSION = "1.00";

use lib (
    '/home/ksieber/scripts/',                       '/home/ksieber/perl5/lib/perl5/',
    '/local/projects-t3/HLGT/scripts/lgtseek/lib/', '/local/projects/ergatis/package-driley/lib/perl5/x86_64-linux-thread-multi/'
);
use warnings;
use strict;
use LGTSeek;
use print_call;
use run_cmd;
use linecount;
use read_in_list;
use read_bam;
use Math::Round;
use setup_input;
use File::Basename;
use Carp;
$Carp::MaxArgLen = 0;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
my %options;
my $results = GetOptions(
    \%options,    'input|i=s',        'input_list|I=s', 'bam|b=s',           'bam_list|B=s', 'bam_total_reads|T=i',
    'sub_name=s', 'output_style=s',   'output_dir|o=s', 'output_prefix|p=s', 'output|O=s',   'sort_input=i',
    'Qsub|q=i',   'Qsub_iterate|Q=i', 'help|?'
) or die "\n*** Error *** Unrecognized command line option. Please try again.\n\n";

if ( $options{help} ) { &help; }    ## @ end of script
if ( !defined $options{bam} and !defined $options{bam_list} ) {
    die "Error: No bam(s) given. Please try again using --bam=/some/file.bam or --bam_list=/some/bams.list";
}
if ( defined $options{Qsub} and $options{Qsub} == 1 ) {
    if ( !defined $options{sub_name} ) { $options{sub_name} = "calcRPKM"; }
    if ( defined $options{input_list} ) { $options{Qsub_iterate} = 1; $options{Qsub} = 0; }
    Qsub_script( \%options );
}

my $lgtseq = LGTSeek->new2( \%options );

my $bams = defined $options{bam} ? [ $options{bam} ] : read_in_list( $options{bam_list} );
my ( $fn, $path, $suf ) = fileparse( "$bams->[0]", @{ $lgtseq->{bam_suffix_list} } );
my $output_dir    = defined $options{output_dir}    ? $options{output_dir}    : $path;
my $output_prefix = defined $options{output_prefix} ? $options{output_prefix} : $fn;
my $output        = defined $options{output}        ? $options{output}        : "$output_dir\/$output_prefix\_rpkm.txt";
my $out_fh;
if ( !defined $options{output_dir} and !defined $options{output_prefix} and !defined $options{output} ) {
    $out_fh = *STDOUT;
}
else {
    open( $out_fh, ">", "$output" ) or die "Error: Unable to open the output: $output\n";
}
my $process_all_transcripts = ( defined $options{input} and $options{input} =~ /^all$/ ) ? 1 : 0;
if ( defined $options{sort_input} and $options{sort_input} == 1 ) { &sort_input_bam; }

my $transcripts = &pull_transcript_ids_and_lengths;
$transcripts = &add_transcript_counts($transcripts);
$transcripts = &calc_transcript_rpkm($transcripts);
&print_rpkm($transcripts);

## Woot, done.

###############################
######### SUBROUTINES #########
###############################

sub print_rpkm {
    my $transcripts = shift;
    ## Print Header
    my $time_stamp                = gmtime();
    my $approximate_bam_fn_length = length( $bams->[0] ) + 10;
    my $output_style              = defined $options{output_style} ? $options{output_style} : "pretty";

    if ( $output_style eq "tdo" ) {
        print $out_fh "Bam";
        foreach my $id ( sort keys %{ $transcripts->{'length'} } ) { printf $out_fh "\t$id"; }
        print $out_fh "\n";
        ## Print actual data now
        foreach my $bam (@$bams) {
            print "$bam";
            foreach my $id ( sort keys %{ $transcripts->{'length'} } ) {
                print $out_fh "\t$transcripts->{$bam}->{$id}->{rpkm}";
            }
            print $out_fh "\n";
        }
    }
    elsif ( $output_style eq "R" ) {
        print $out_fh "Bam\tTranscript\tRPKM\n";
        ## Print actual data now
        foreach my $bam (@$bams) {
            foreach my $id ( sort keys %{ $transcripts->{'length'} } ) {
                printf $out_fh "$bam\t$id\t$transcripts->{$bam}->{$id}->{rpkm}\n";
            }
        }
    }
    elsif ( $output_style eq "pretty" ) {
        printf $out_fh ( "%-*s", $approximate_bam_fn_length, "#Bam" );
        foreach my $id ( sort keys %{ $transcripts->{'length'} } ) { printf $out_fh ( "%-20s", "$id" ); }
        printf $out_fh ( "%24s%47s", "calc_rpkm.PL-Version:$VERSION", "Time_stamp: $time_stamp" );
        print $out_fh "\n";
        ## Print actual data now
        foreach my $bam (@$bams) {
            printf $out_fh ( "%-*s", $approximate_bam_fn_length, "$bam" );
            foreach my $id ( sort keys %{ $transcripts->{'length'} } ) {
                printf $out_fh ( "%-20s", "$transcripts->{$bam}->{$id}->{rpkm}" );
            }
            print $out_fh "\n";
        }
    }
    else {
        die "Error: Unable to determine output style. Please see --help and try again.\n";
    }

    close $out_fh;
}

sub calc_transcript_rpkm {
    my $transcripts = shift;
    foreach my $bam (@$bams) {
        chomp(
            my $bam_total_read_count
                = ( defined $options{bam_total_reads} and $options{bam_total_reads} =~ /\d+/ )
            ? $options{bam_total_reads}
            : `samtools view -F 3840 $bam | wc -l`
        );

        foreach my $id ( sort keys %{ $transcripts->{'length'} } ) {
            $transcripts->{"$bam"}->{"$id"}->{'rpkm'}
                = ( defined $transcripts->{"$bam"}->{"$id"}->{'count'} and $transcripts->{"$bam"}->{"$id"}->{'count'} > 0 )
                ? nearest( .001,
                ( ( 10**9 * $transcripts->{"$bam"}->{"$id"}->{'count'} ) / ( $bam_total_read_count * $transcripts->{'length'}->{"$id"} ) ) )
                : "NA";
        }
    }
    return $transcripts;
}

sub add_transcript_counts {
    my $transcripts = shift;
    if   ( $process_all_transcripts == 1 ) { $transcripts = &count_all_transcript($transcripts); }
    else                                   { $transcripts = &count_desired_transcripts($transcripts); }
    return $transcripts;
}

sub count_all_transcript {
    my $transcripts = shift;
    foreach my $bam (@$bams) {
        open( my $IN_fh, "-|", "samtools view -F 3840 $bam" ) or die "Error: Unable to open the input bam: $bam\n";
        while (<$IN_fh>) {
            chomp( my $line = $_ );
            my $id = ( split /\t/, $line )[2];
            if ( $id =~ /\w+/ ) {
                $transcripts->{"$bam"}->{"$id"}->{'count'}++;
            }
        }
        close $IN_fh;
    }
    return $transcripts;
}

sub count_desired_transcripts {
    my $transcripts = shift;
    my $count_flag = defined $options{count_flag} ? $options{count_flag} : "-F 3844";
    foreach my $bam (@$bams) {
        foreach my $id ( keys %{ $transcripts->{'length'} } ) {
            chomp( my $id_count = `samtools view $count_flag $bam $id | wc -l` );
            $transcripts->{"$bam"}->{"$id"}->{'count'} = $id_count;
        }
    }
    return $transcripts;
}

sub pull_transcript_ids_and_lengths {
    my $transcripts;
    my $desired_transcript_ids = ( $process_all_transcripts != 1 ) ? &pull_desired_transcript_ids : undef;
    my $bam_header             = run_cmd("samtools view -H $bams->[0]");
    my @header_lines           = split( /\n/, $bam_header );
    foreach my $line (@header_lines) {
        next if $line !~ /^\@SQ/;
        my ( $sq, $id_col, $lngth_col ) = split( /\t/, $line );
        $id_col =~ /SN:([a-zA-Z0-9\|\:\-\_\.]+)/;
        chomp( my $id = $1 );
        next if ( defined $desired_transcript_ids and !$desired_transcript_ids->{$id} );
        $lngth_col =~ /LN:(\d+)/;
        chomp( my $length = $1 );
        $transcripts->{'length'}->{"$id"} = $length;
    }
    return $transcripts;
}

sub pull_desired_transcript_ids {
    my $ids_array_ref = setup_input( \%options );
    my $ids_hash_ref;
    foreach my $id (@$ids_array_ref) { $ids_hash_ref->{$id}++; }
    return $ids_hash_ref;
}

sub sort_input_bam {
    my $threads  = defined $options{threads}  ? $options{threads}  : 3;
    my $sort_mem = defined $options{sort_mem} ? $options{sort_mem} : "1G";
    my ( $bam_fn, $bam_path, $bam_suf ) = fileparse( $options{bam}, @{ $lgtseq->{bam_suffix_list} } );
    run_cmd("samtools sort -@ $threads -m $sort_mem $options{bam} $bam_path$bam_fn\.srt");
    run_cmd("samtools index $bam_path$bam_fn\.srt.bam");
    $options{bam} = "$bam_path$bam_fn\.srt.bam";
}

sub help {
    die "\nThis script will calculate the RPKM the --input gene(s)
    --input|i=              Gene ID that matches the bam header to calc rpkm for. May also use \'-i all\' to process all genes.
    --input_list|I=         List of gene ids, 1 per line. May also be multiple id's comma seperated.
    --bam|b=                Bam file with reads map to appropriate ref.
    --bam_total_reads|T=    # of total reads in a sample. Optional, saves time when input is only a few genes.
    --sort_input=           <0|1> [0] 1= Position sort the input bam. 
    --output|O=             {/file/for/output.txt}
    --output_dir|o=         {/directory/for/output/}prefix.txt
    --output_prefix|p=      /directory/for/output/{prefix}.txt
       If no above --output* is given output will go to STDOUT.
    --output_style=         < tdo | R | pretty > 
    --Qsub|q=               <0|1> [0] 1=Submit each bam as a seperate job
    --Qsub_iterate|Q=       <0|1> [0] 1=Submit 1 job with a list of bams.\n\n";
}
