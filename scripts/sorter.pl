#
# Fanboy Adblock Sorter v1.5 (22/03/2011)
#
# Dual License CCby3.0/GPLv2
# http://creativecommons.org/licenses/by/3.0/
# http://www.gnu.org/licenses/gpl-2.0.html
#
# Usage: perl sort.pl <filename.txt>
#
use strict;
use warnings;
use File::Copy;

sub output {
    my( $lines, $fh ) = @_;
    return unless @$lines;
    print $fh shift @$lines; # print first line
    print $fh sort { lc $a cmp lc $b } @$lines;  # print rest
    return;
}
# ======== Main ========
#

foreach my $filename (@ARGV) {

    my $outFn = "$filename.out";
    # die "output file $outFn already exists, aborting\n" if -e $outFn;
    # prereqs okay, set up input, output and sort buffer
    #
    open my $fh, '<', $filename or die "open $filename: $!";
    open my $fhOut, '>', $outFn or die "open $outFn: $!";

    # Mark filenames for moving (overwriting..)
    #
    my $fileToBeCopied = $outFn;
    my $newFile = $filename;
    # Keep in Binary thus keep in Unix formatted text.
    #
    binmode($fhOut);
    my $current = [];
    # Process data
    # Check "!", "[]" and "#" and ";" (Firefox and Opera)
    #
    while ( <$fh> ) {
        if ( m/^(?:[!\[]|[#|;]\s)/ ) {
            output $current, $fhOut;
            $current = [ $_ ];
        }
        else {
            push @$current, $_;
        }
    }
    # Finish Up.
    #
    output $current, $fhOut;
    close $fhOut;
    close $fh;
    # Move backup file.out (sorted) overwrite original (non sorted)
    #
    move($fileToBeCopied, $newFile);

}


