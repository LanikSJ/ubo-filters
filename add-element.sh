#!/bin/bash
perl scripts/sorter.pl $1
perl scripts/addChecksum.pl $1
git add -A; git commit -S -am "$(echo "$2" | sed "s!\.\([^./]*\(/\|$\)\)! \1!")"
git push -f origin master
