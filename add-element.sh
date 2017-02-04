#!/bin/bash
git pull origin master
perl scripts/sorter.pl ubo-filters.txt
perl scripts/addChecksum.pl ubo-filters.txt
git add -A; git commit -S -am "$(echo "$1" | sed "s!\.\([^./]*\(/\|$\)\)! \1!")"
git push origin master
