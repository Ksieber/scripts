#!/usr/bin/perl -I /home/ksieber/perl5/lib/perl5/ -I /home/ksieber/scripts/
use warnings;
no warnings 'uninitialized';
use strict;
use lib ( "/local/projects-t3/HLGT/scripts/lgtseek/lib/", "/local/projects/ergatis/package-driley/lib/perl5/x86_64-linux-thread-multi/" )
    ;    ### May need to change this depending on where the script is being run
use LGTSeek;
use run_cmd;
use setup_input;
use Time::SoFar;
use File::Basename;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
my %options;
my $results = GetOptions( \%options, 'input|i=s', 'input_list|I=s', 'output_dir|o=s', 'output_name=s', 'Qsub|Q=i', 'subdirs=s', 'conf_file=s', 'help', 'sub_name=s', 'sub_mail=s', );

if ( $options{help} ) {
    die "Help:
    This script will merge the output files of lgt_seq.pl.
    ----------------------------------------------------------------------------------------
    --input|i=      Directory to merge files from. Subdirectories in this directory should contain lgt_seq.pl outputs.
    --input_list|I=     List of input directories.
    ----------------------------------------------------------------------------------------
    --output_dir|o=     Directory for output.
      --subdirs=        <0|1> [0] 1= Make a new directory within output_dir for each input directory.
      --output_name=        Prefix name for the merged output. [Input dir name]
    ----------------------------------------------------------------------------------------
    --Qsub|Q=i      <0|1> [0] 1= Qsub the job to the grid. 
     --sub_mail=             [0] 1= email user\@som.umaryland.edu when job is complete & with stats. Can also specify --sub_mail=specific\@email.foo
    ----------------------------------------------------------------------------------------
    --help
    --conf_file=        [~/.lgtseek.conf]
    ----------------------------------------------------------------------------------------\n";
}

if ( !$options{input} && !$options{input_list} ) { die "Must give an input. Use --input or --input_list\n"; }
if ( !$options{output_dir} ) { die "Must use --output_dir=\n"; }
my $subdirs = defined $options{subdirs} ? "1" : "0";
my $input = setup_input( \%options );
run_cmd("mkdir -p $options{output_dir}");

if ( $options{Qsub} ) {
    $options{sub_name} = defined $options{sub_name} ? $options{sub_name} : "mergelgtseq";
    Qsub_script( \%options );
}

my $lgtseek = LGTSeek->new2( \%options );

my @bam_suffix_to_merge = ( 'microbiome.bam', 'lgt_host.bam', 'integration_site_donor_host.bam', 'lgt_host_filtered.bam', 'lgt_host_filtered_validated.bam', 'integration_site_donor_donor.bam',
    'microbiome_filtered.bam' );

my @txt_suffix_to_merge = (
    'by_clone.txt',          'by_clone.list',         'by_trace.txt',                           'post_processing.tab',
    'lgt_host_lineage1.out', 'lgt_host_lineage2.out', 'microbiome_lca-bwa_independent_lca.txt', 'microbiome_lca-bwa.txt',
    'lgt_lca-bwa.txt',       'prinseq-bad-ids.out',
);

my $input_path;
if ( defined $options{input_list} ) {
    my ( $fn, $path, $suf ) = fileparse( $options{input_list} );
    my @split_path = split( /\//, $path );
    $input_path = $split_path[-1];
}
elsif ( $options{input} && -e $options{input} ) {
    my @split_path = split( /\//, $options{input} );
    $input_path = $split_path[-1];
}
my $name = defined $options{output_name} ? $options{output_name} : $input_path;

foreach my $dir (@$input) {
    my $output_dir;
    if ( $subdirs == 1 ) {
        run_cmd("mkdir -p $options{output_dir}/$name");
        $output_dir = "$options{output_dir}/$name";
    }
    else {
        $output_dir = "$options{output_dir}";
    }

    ## Process all the txt files for merging
    print STDERR "Input_dir: $dir\nOutput_name: $name\nOutput_dir: $output_dir\n";
    foreach my $txt_suffix (@txt_suffix_to_merge) {
        chomp( my @list_to_merge = `find $dir -name '*$txt_suffix'` );
        if ( scalar( @list_to_merge == 0 ) ) { print STDERR "*** Warning *** : Did not find any *$txt_suffix in: $dir\n"; next; }
        my $output = "$output_dir/$name\_$txt_suffix";
        if ( $txt_suffix =~ /by_trace.txt/ ) {
            run_cmd("head -n1 $list_to_merge[0] > $output");    # Grab the header and put it into the output file
            foreach my $file (@list_to_merge) {
                next if ( run_cmd("head -n2 $file | wc -l") != 2 );
                run_cmd("grep -v Read $file >> $output");       # Merge all the files together skipping the header
            }
        }
        else {
            foreach my $file (@list_to_merge) {
                run_cmd("cat $file >> $output");
            }
        }
    }

    ## Process all the bam files for merging
    foreach my $bam_suffix (@bam_suffix_to_merge) {
        chomp( my @list_to_merge = `find $dir -name '*$bam_suffix'` );
        if ( scalar( @list_to_merge == 0 ) ) { print STDERR "*** Warning *** : Did not find any *$bam_suffix in: $dir\n"; next; }
        my $output = "$output_dir/$name\_$bam_suffix";
        my $header = undef;                              ## Trying to come up with a way to grab a header while checking to make sure at least 1 file has data in it.
        for ( my $i = 0; $i < scalar @list_to_merge; $i++ ) {
            next if ( $lgtseek->empty_chk( { input => $list_to_merge[$i] } ) == 1 );    ## Skip the bam if it is empty
            $header = run_cmd("samtools view -H $list_to_merge[$i]");                   ## else grab the header
        }
        next if ( $header !~ /\S+/ );                                                   ## If none of the bams in the @list_to_merge have data header should be undef still and we skip this suffix
        open( my $out, "| samtools view -S - -bo $output" ) or die "Can not open output: $output\n";
        print $out "$header\n";
        foreach my $bam (@list_to_merge) {
            next if ( $lgtseek->empty_chk( { input => $bam } ) == 1 );
            open( my $in, "-|", "samtools view $bam" ) or die "Can not open input: $bam\n";
            while (<$in>) {
                print $out "$_";
            }
            close $in or die "Can not close input: $input because: $!\n";
        }
        close $out or die "Can't close output: $output because: $!\n";
    }
    print STDERR "====== Completed merging: $dir ======\n";
}

print_complete( \%options );