#!/usr/bin/env bash

cpan install Path:Tiny
perl scripts/sorter.pl "$1" && perl scripts/addChecksum.pl "$1"
