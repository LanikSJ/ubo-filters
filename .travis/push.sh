#!/usr/bin/env bash

git config --global user.email "travis@travis-ci.org"
git config --global user.name "Travis CI"

cd filters
files=ls -alh |grep -Ev "drwx|total" |awk '{print $NF}' |grep -i -Ev "combined|readme|ubo"
for i in $files; do cat $i |grep -i -Ev "\!|adblock" |sed -r '/^\s*$/d' >> combined-filters.txt ; done
cd .. && /checksum-sort.sh filters/combined-filters.txt

git checkout -b master
git add . *.txt
git commit --message "Travis build: $TRAVIS_BUILD_NUMBER"

git remote add origin https://${GH_TOKEN}@github.com/LanikSJ/ubo-filters.git > /dev/null 2>&1
git push --quiet --set-upstream origin master
