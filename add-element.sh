#!/bin/bash
perl scripts/sorter.pl $1 && perl scripts/addChecksum.pl $1
git add -A; git commit -S -am $2
git push -f origin master
