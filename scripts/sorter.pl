#!/usr/bin/env perl

#
# Enhanced Fanboy Adblock Sorter v2.0 (2025)
# Based on original v1.5 (22/03/2011)
#
# Dual License CCby3.0/GPLv2
# http://creativecommons.org/licenses/by/3.0/
# http://www.gnu.org/licenses/gpl-2.0.html
#
# Usage: perl sorter.pl <filename.txt> [options]
# Options:
#   --help, -h          Show this help message
#   --verbose, -v       Enable verbose output
#   --backup             Create backup files (not created by default)
#   --backup-suffix     Suffix for backup files (default: .backup)
#   --no-backup         Don't create backup files (default behavior)
#   --dry-run           Show what would be done without making changes
#

use strict;
use warnings;
use utf8;
use File::Copy;
use File::Basename;
use Getopt::Long;
use Pod::Usage;

# Version information
our $VERSION = '2.0';

# Configuration variables
my $verbose       = 0;
my $help          = 0;
my $backup_suffix = '.backup';
my $no_backup     = 1;           # Default to no backup
my $create_backup = 0;           # Only create backup when explicitly requested
my $dry_run       = 0;

# Parse command line options
GetOptions(
    'help|h'          => \$help,
    'verbose|v'       => \$verbose,
    'backup-suffix=s' => \$backup_suffix,
    'backup'          => \$create_backup,
    'no-backup'       => \$no_backup,
    'dry-run'         => \$dry_run,
) or pod2usage(2);

# Handle backup options (--backup overrides default --no-backup)
if ($create_backup) {
    $no_backup = 0;
}

# Show help if requested
pod2usage(1) if $help;

# Check if files were provided
if ( @ARGV == 0 ) {
    print STDERR "Error: No input files specified\n";
    print STDERR "Usage: $0 <filename.txt> [options]\n";
    print STDERR "Use --help for more information\n";
    exit 1;
}

# Logging functions
sub log_info {
    my ($message) = @_;
    print STDERR "[INFO] $message\n" if $verbose;
}

sub log_error {
    my ($message) = @_;
    print STDERR "[ERROR] $message\n";
}

sub log_warning {
    my ($message) = @_;
    print STDERR "[WARNING] $message\n";
}

# Enhanced output function with better error handling
sub output_section {
    my ( $lines, $fh, $section_type ) = @_;
    return unless @$lines;

    # Print the first line (header/comment)
    my $header = shift @$lines;
    print $fh $header;

    # Sort and print the rest of the lines
    if (@$lines) {
        my @sorted_lines = sort { lc($a) cmp lc($b) } @$lines;
        print $fh @sorted_lines;

        log_info( "Sorted "
              . scalar(@sorted_lines)
              . " lines in $section_type section" );
    }

    return;
}

# Validate file before processing
sub validate_file {
    my ($filename) = @_;

    unless ( -f $filename ) {
        log_error("File '$filename' does not exist or is not a regular file");
        return 0;
    }

    unless ( -r $filename ) {
        log_error("File '$filename' is not readable");
        return 0;
    }

    unless ( -w $filename ) {
        log_error("File '$filename' is not writable");
        return 0;
    }

    # Check if file is empty
    if ( -z $filename ) {
        log_warning("File '$filename' is empty");
        return 0;
    }

    return 1;
}

# Create backup of original file
sub create_backup {
    my ($filename) = @_;

    return 1 if $no_backup;

    my $backup_file = $filename . $backup_suffix;

    if ( -e $backup_file ) {
        log_warning(
            "Backup file '$backup_file' already exists, will overwrite");
    }

    if ($dry_run) {
        log_info("Would create backup: $backup_file");
        return 1;
    }

    if ( copy( $filename, $backup_file ) ) {
        log_info("Created backup: $backup_file");
        return 1;
    }
    else {
        log_error("Failed to create backup '$backup_file': $!");
        return 0;
    }
}

# Get file statistics
sub get_file_stats {
    my ($filename) = @_;

    open my $fh, '<:encoding(UTF-8)', $filename or return {};

    my $total_lines   = 0;
    my $comment_lines = 0;
    my $filter_lines  = 0;
    my $empty_lines   = 0;

    while ( my $line = <$fh> ) {
        $total_lines++;

        if ( $line =~ /^\s*$/ ) {
            $empty_lines++;
        }
        elsif ( $line =~ /^(?:[!\[]|[#|;]\s)/ ) {
            $comment_lines++;
        }
        else {
            $filter_lines++;
        }
    }

    close $fh;

    return {
        total_lines   => $total_lines,
        comment_lines => $comment_lines,
        filter_lines  => $filter_lines,
        empty_lines   => $empty_lines,
    };
}

# Process a single file
sub process_file {
    my ($filename) = @_;

    log_info("Processing file: $filename");

    # Validate file
    unless ( validate_file($filename) ) {
        return 0;
    }

    # Get initial statistics
    my $initial_stats = get_file_stats($filename);
    log_info( "Initial stats - Total: $initial_stats->{total_lines}, "
          . "Comments: $initial_stats->{comment_lines}, "
          . "Filters: $initial_stats->{filter_lines}, "
          . "Empty: $initial_stats->{empty_lines}" );

    # Create backup
    unless ( create_backup($filename) ) {
        return 0;
    }

    if ($dry_run) {
        log_info("Dry run mode - would sort file '$filename'");
        return 1;
    }

    # Set up file handles
    my $temp_file = "$filename.tmp.$$";

    # Open input file with UTF-8 encoding
    open my $input_fh, '<:encoding(UTF-8)', $filename or do {
        log_error("Cannot open input file '$filename': $!");
        return 0;
    };

    # Open output file with UTF-8 encoding
    open my $output_fh, '>:encoding(UTF-8)', $temp_file or do {
        log_error("Cannot open temporary file '$temp_file': $!");
        close $input_fh;
        return 0;
    };

    # Process the file
    my $current_section = [];
    my $section_count   = 0;
    my $line_number     = 0;

    while ( my $line = <$input_fh> ) {
        $line_number++;

        # Check for section headers (comments starting with !, [, #, or ;)
        if ( $line =~ /^(?:[!\[]|[#|;]\s)/ ) {

            # Output previous section if it exists
            if (@$current_section) {
                output_section( $current_section, $output_fh,
                    "section $section_count" );
                $section_count++;
            }

            # Start new section with this header line
            $current_section = [$line];
        }
        else {
            # Add line to current section
            push @$current_section, $line;
        }
    }

    # Output final section
    if (@$current_section) {
        output_section( $current_section, $output_fh,
            "section $section_count" );
        $section_count++;
    }

    # Close file handles
    close $input_fh;
    close $output_fh;

    # Replace original file with sorted version
    unless ( move( $temp_file, $filename ) ) {
        log_error("Failed to replace original file '$filename': $!");
        unlink $temp_file;    # Clean up temporary file
        return 0;
    }

    # Get final statistics
    my $final_stats = get_file_stats($filename);
    log_info( "Final stats - Total: $final_stats->{total_lines}, "
          . "Comments: $final_stats->{comment_lines}, "
          . "Filters: $final_stats->{filter_lines}, "
          . "Empty: $final_stats->{empty_lines}" );

    log_info("Successfully processed $section_count sections in '$filename'");

    return 1;
}

# Main execution
sub main {
    my $success_count = 0;
    my $total_files   = @ARGV;

    log_info("Starting sorter v$VERSION");
    log_info("Processing $total_files file(s)");

    foreach my $filename (@ARGV) {
        if ( process_file($filename) ) {
            $success_count++;
            print "Successfully sorted: $filename\n" unless $verbose;
        }
        else {
            log_error("Failed to process: $filename");
        }
    }

    # Summary
    if ( $total_files > 1 ) {
        log_info(
            "Summary: $success_count/$total_files files processed successfully"
        );
    }

    if ( $success_count == $total_files ) {
        log_info("All files processed successfully");
        exit 0;
    }
    else {
        log_error("Some files failed to process");
        exit 1;
    }
}

# Run main function
main();

__END__

=head1 NAME

sorter.pl - Enhanced Fanboy Adblock Filter Sorter

=head1 SYNOPSIS

sorter.pl [options] file1.txt [file2.txt ...]

=head1 OPTIONS

=over 4

=item B<--help, -h>

Show this help message and exit.

=item B<--verbose, -v>

Enable verbose output with detailed processing information.

=item B<--backup>

Create backup files before processing (not created by default).

=item B<--backup-suffix SUFFIX>

Specify suffix for backup files (default: .backup).

=item B<--no-backup>

Don't create backup files before processing (default behavior).

=item B<--dry-run>

Show what would be done without making any changes.

=back

=head1 DESCRIPTION

This script sorts adblock filter files by organizing them into sections based on
comment headers and sorting the filter rules within each section alphabetically.

The script recognizes section headers that start with:
- ! (standard adblock comments)
- [ (section markers)
- # (hash comments)
- ; (semicolon comments, for Firefox/Opera compatibility)

=head1 EXAMPLES

    # Basic usage (no backup created by default)
    perl sorter.pl filters.txt

    # Create backup with default suffix (.backup)
    perl sorter.pl --backup filters.txt

    # Verbose mode with backup and custom suffix
    perl sorter.pl --verbose --backup --backup-suffix .bak filters.txt

    # Process multiple files (no backups by default)
    perl sorter.pl file1.txt file2.txt file3.txt

    # Dry run to see what would be changed
    perl sorter.pl --dry-run --verbose filters.txt

=head1 AUTHOR

Enhanced version based on original Fanboy Adblock Sorter v1.5

=head1 LICENSE

Dual License CCby3.0/GPLv2

=cut
