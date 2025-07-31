#!/usr/bin/env perl

# Copyright 2011 Wladimir Palant
# https://palant.de/
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#############################################################################
# Script to add checksums to downloadable subscriptions. The checksum will  #
# be validated by Adblock Plus on download and checksum mismatches          #
# (broken downloads) will be rejected.                                      #
#                                                                           #
# Enhanced version with improved error handling and validation.             #
#                                                                           #
# Usage:                                                                    #
#   perl addChecksum.pl [--verbose] [--force] subscription.txt             #
#                                                                           #
# Options:                                                                  #
#   --verbose    Enable verbose output                                      #
#   --force      Force update even if checksum hasn't changed              #
#                                                                           #
# Note: your subscription file should be saved in UTF-8 encoding, otherwise #
# the generated checksum might be incorrect.                                #
#                                                      AdblockPlus.Org      #
#############################################################################

use strict;
use warnings;
use Path::Tiny;
use Digest::MD5  qw(md5_base64);
use Encode       qw(encode_utf8 is_utf8);
use POSIX        qw(strftime);
use Getopt::Long qw(GetOptions);
use feature 'unicode_strings';

# Command line options
my $verbose = 0;
my $force   = 0;
my $help    = 0;

GetOptions(
    'verbose|v' => \$verbose,
    'force|f'   => \$force,
    'help|h'    => \$help,
) or die "Error in command line arguments\n";

if ($help) {
    print <<'EOF';
Usage: perl addChecksum.pl [OPTIONS] subscription.txt

Options:
  --verbose, -v    Enable verbose output
  --force, -f      Force update even if checksum hasn't changed
  --help, -h       Show this help message

Examples:
  perl addChecksum.pl filters.txt
  perl addChecksum.pl --verbose --force filters.txt

EOF
    exit 0;
}

die "Usage: $^X $0 [--verbose] [--force] subscription.txt\n" unless @ARGV;

my $file = shift;

# Enhanced file validation
die "Specified file: $file doesn't exist!\n"         unless ( -e $file );
die "Specified file: $file is not a regular file!\n" unless ( -f $file );
die "Specified file: $file is not readable!\n"       unless ( -r $file );
die "Specified file: $file is not writable!\n"       unless ( -w $file );

print "Processing file: $file\n" if $verbose;

# Read file with enhanced error handling
my $data;
eval {
    $data = path($file)->slurp_utf8;
    print "Successfully read file (${\(length($data))} characters)\n"
      if $verbose;
};
if ($@) {
    die "Failed to read file '$file': $@\n";
}

# Validate UTF-8 encoding
unless ( is_utf8($data) ) {
    print "Warning: File does not appear to be valid UTF-8\n" if $verbose;
}

# Get existing checksum
$data =~ /^.*!\s*checksum[\s\-:]+([\w\+\/=]+).*\n/gmi;
my $oldchecksum = $1;

if ($verbose) {
    if ($oldchecksum) {
        print "Found existing checksum: $oldchecksum\n";
    }
    else {
        print "No existing checksum found\n";
    }
}

# Remove already existing checksum
my $checksum_removed = $data =~ s/^.*!\s*checksum[\s\-:]+([\w\+\/=]+).*\n//gmi;
print "Removed existing checksum line\n" if $verbose && $checksum_removed;

# Calculate new checksum: remove all CR symbols and empty
# lines and get an MD5 checksum of the result (base64-encoded,
# without the trailing = characters)
my $checksumData = $data;
$checksumData =~ s/\r//g;
$checksumData =~ s/\n+/\n/g;

print
"Calculating checksum for ${\(length($checksumData))} characters of normalized data\n"
  if $verbose;

# Calculate new checksum
my $checksum = md5_base64( encode_utf8($checksumData) );
print "New checksum: $checksum\n" if $verbose;

# Check if checksum has changed (unless --force is used)
if ( $oldchecksum && $checksum eq $oldchecksum && !$force ) {
    print "Checksum unchanged, no update needed\n" if $verbose;
    die "List has not changed.\n";
}
elsif ( $oldchecksum && $checksum eq $oldchecksum && $force ) {
    print "Checksum unchanged, but forcing update due to --force flag\n"
      if $verbose;
}
elsif ( $oldchecksum && $checksum ne $oldchecksum ) {
    print "Checksum changed from $oldchecksum to $checksum\n" if $verbose;
}

# Update the date and time.
my $updated = strftime( "%Y-%m-%d %H:%M UTC", gmtime );
my $date_updated =
  $data =~ s/(^.*!.*(Last modified|Updated):\s*)(.*)\s*$/$1$updated/gmi;
if ($verbose) {
    if ($date_updated) {
        print "Updated timestamp to: $updated\n";
    }
    else {
        print "No timestamp field found to update\n";
    }
}

# Update version
my $version         = strftime( "%Y%m%d%H%M", gmtime );
my $version_updated = $data =~ s/^.*!\s*Version:.*/! Version: $version/gmi;
if ($verbose) {
    if ($version_updated) {
        print "Updated version to: $version\n";
    }
    else {
        print "No version field found to update\n";
    }
}

# Recalculate the checksum as we've altered the date/version
$checksumData = $data;
$checksumData =~ s/\r//g;
$checksumData =~ s/\n+/\n/g;
$checksum = md5_base64( encode_utf8($checksumData) );

print "Final checksum after metadata updates: $checksum\n" if $verbose;

# Insert checksum into the file
my $checksum_inserted = $data =~ s/(\r?\n)/$1! Checksum: $checksum$1/;
if ($verbose) {
    if ($checksum_inserted) {
        print "Inserted checksum line\n";
    }
    else {
        print "Warning: Failed to insert checksum line\n";
    }
}

# Write file with enhanced error handling
eval {
    path($file)->spew_utf8($data);
    print "Successfully wrote updated file\n" if $verbose;
};
if ($@) {
    die "Failed to write file '$file': $@\n";
}

print "Checksum processing completed successfully\n" if $verbose;
