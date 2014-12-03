#!/usr/bin/perl -I /home/ksieber/perl5/lib/perl5/ -I /home/ksieber/scripts/
use warnings;
use strict;
use run_cmd;
use print_call;
use File::Basename;
use Statistics::R;

use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
my %options;
my $results = GetOptions( \%options, 'input|i=s', 'output_dir|o=s', 'graph|g=i', 'help|?' ) or die "Unrecognized command line option. Please try agian.\n";

if ( !$options{input} ) { die "Error: Must give an input directory merge JSD_titration_summary.txt from. Please try again.\n"; }
my $files = run_cmd("find $options{input} -name \'*JSD_titration_summary.txt\'");
my @files_to_merge = split( /\n/, $files );

my $output_dir = defined $options{output_dir} ? $options{output_dir} : $options{input};

open( my $OUT1, ">", "$output_dir/merged_jsd_vals.txt" )    or die "Error: Unable to open output: $output_dir/merged_jsd_vals.txt";
open( my $OUT2, ">", "$output_dir/merged_jsd_ci-mins.txt" ) or die "Error: Unable to open output: $output_dir/merged_jsd_vals.txt";
open( my $OUT3, ">", "$output_dir/merged_jsd_ci-maxs.txt" ) or die "Error: Unable to open output: $output_dir/merged_jsd_vals.txt";

foreach my $file ( sort @files_to_merge ) {
    chomp($file);
    my ( $fn, $path, $suf ) = fileparse( $file, ".txt" );
    my @split_path = split( /\//, $path );
    open( my $FH, "<", $file ) or die "Error: Unable to open input file: $file\n";

    my $jsd_values_line_string  = <$FH>;
    my $jsd_ci_mins_line_string = <$FH>;
    my $jsd_ci_maxs_line_string = <$FH>;

    chomp($jsd_values_line_string);
    chomp($jsd_ci_mins_line_string);
    chomp($jsd_ci_maxs_line_string);

    my @jsd_values_line = split( /\s+/, $jsd_values_line_string );
    shift(@jsd_values_line);    # Remove header tab
    print $OUT1 "$split_path[-1]\t";
    print $OUT1 join( "\t", @jsd_values_line ) . "\n";

    my @jsd_ci_mins_line = split( /\s+/, $jsd_ci_mins_line_string );
    shift(@jsd_ci_mins_line);    # Remove header tab
    print $OUT2 "$split_path[-1]\t";
    print $OUT2 join( "\t", ( $split_path[-1], @jsd_ci_mins_line[ 1 .. 3 ] ) ) . "\n";

    my @jsd_ci_maxs_line = split( /\s+/, $jsd_ci_maxs_line_string );
    shift(@jsd_ci_maxs_line);    # Remove header tab
    print $OUT3 "$split_path[-1]\t";
    print $OUT3 join( "\t", ( $split_path[-1], @jsd_ci_maxs_line[ 1 .. 3 ] ) ) . "\n";

    close $FH;
}

close $OUT1;
close $OUT2;
close $OUT3;

if ( defined $options{graph} and $options{graph} == 1 ) {
    my @data_files = find_files( $options{input}, "*JSD_values_conf-intrvls.txt" );
    my @read_number_list;
    my @jsd_list;
    my %uniq_read_numbers;
    foreach my $file (@data_files) {
        my ( $fn, $path, $suf ) = fileparse( $file, ".txt" );
        my @split_path = split( /\//, $path );
        $split_path[-1] =~ /(\d+)\_reads/;
        my $read_number = $1;
        $uniq_read_numbers{$read_number}++;

        # my $read_number = $split_path[-1];
        open( my $FH, "<", $file ) or die "Error: Unable to open input file: $file\n";
        while (<$FH>) {
            chomp;
            next if ( $_ =~ /^\#/ );
            next if ( $_ !~ /\w+/ );
            my ($jsd) = ( split /\s+/, $_ )[1];
            push( @read_number_list, $read_number );
            push( @jsd_list,         $jsd );
        }
        close $FH;
    }
    my $R = Statistics::R->new( r_bin => '/home/ksieber/bin/R' );
    $R->run('library(ggplot2)');
    ## Initialize the read number and jsd list

    my $read_number_string_for_R;
    foreach my $read_number (@read_number_list) { $read_number_string_for_R = $read_number_string_for_R . "$read_number,"; }
    $read_number_string_for_R =~ s/(\,)$//g;    # Remove trailing ","
    $R->run("reads <- c($read_number_string_for_R)");

    my $jsd_string_for_R;
    foreach my $jsd (@jsd_list) { $jsd_string_for_R = $jsd_string_for_R . "$jsd,"; }
    $jsd_string_for_R =~ s/(\,)$//g;            # Remove trailing ","
    $R->run("jsd <- c($jsd_string_for_R)");

    my $number_of_uniq_reads = scalar( keys %uniq_read_numbers );
    $R->run("df<-data.frame(reads, jsd, stringsAsFactors=FALSE)");
    $R->run("pdf(file=\"$output_dir/JSD_merged_plot.pdf\")");
    $R->run(
        "qplot(factor(reads), jsd, data=df, geom=\"boxplot\", xlab=\"reads\", ylab=\"JSD\", fill=factor(reads)) + theme(legend.position=\"none\")"
    );
    $R->run('dev.off()');
}

print_complete( \%options );

__END__
+ scale_fill_gradientn(values=reads, colours = rainbow($number_of_uniq_reads)) +