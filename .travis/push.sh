#!/bin/sh

setup_git() {
  git config --global user.email "travis@travis-ci.org"
  git config --global user.name "Travis CI"
}

combine_filters() {
  cd filters
  files=ls -alh |grep -Ev "drwx|total" |awk '{print $NF}' |grep -i -Ev "readme|ubo"
  for i in $files; do cat $i |grep -i -Ev "\!|adblock" >> combined-filters.txt ; done
}

commit_website_files() {
  git checkout -b master
  git add . *.txt
  git commit --message "Travis build: $TRAVIS_BUILD_NUMBER"
}

upload_files() {
  git remote add origin https://${GH_TOKEN}@github.com/LanikSJ/ubo-filters.git > /dev/null 2>&1
  git push --quiet --set-upstream origin master
}

setup_git
combine_filters
commit_website_files
upload_files
