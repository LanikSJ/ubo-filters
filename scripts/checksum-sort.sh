#!/usr/bin/env bash

cpan install Path:Tiny
perl scripts/sorter.pl "$1" && perl scripts/addChecksum.pl "$1"
echo "Cleaning Up..." && rm -rf ~/.cpan ~/.perl
echo && echo "Done! $1 has been sorted and checksums have been added."
