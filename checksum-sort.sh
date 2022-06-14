#!/usr/bin/env bash

perl scripts/sorter.pl $1 && perl scripts/addChecksum.pl $1
