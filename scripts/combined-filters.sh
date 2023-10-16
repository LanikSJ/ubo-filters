#!/usr/bin/env bash

cd filters || exit
cp template.txt combined-filters.txt

more adback-domains.txt | grep -v ! >>combined-filters.txt
more adkeeper-domains.txt | grep -v ! >>combined-filters.txt
more admaven-domains.txt | grep -v ! >>combined-filters.txt
more admeasures-domains.txt | grep -v ! >>combined-filters.txt
more bt-contentza-domains.txt | grep -v ! >>combined-filters.txt
more cdn-filter-list.txt | grep -v ! >>combined-filters.txt
more cryptomining-domains.txt | grep -v ! >>combined-filters.txt
more freecounterstat-domains.txt | grep -v ! >>combined-filters.txt
more getadmiral-domains.txt | grep -v ! >>combined-filters.txt
more hilltopads-domains.txt | grep -v ! >>combined-filters.txt
more istripper-domains.txt | grep -v ! >>combined-filters.txt
more kitty-domains.txt | grep -v ! >>combined-filters.txt
more macupload-domains.txt | grep -v ! >>combined-filters.txt
more popads-domains.txt | grep -v ! >>combined-filters.txt
more propellerads-domains.txt | grep -v ! >>combined-filters.txt
more toradvertising-domains.txt | grep -v ! >>combined-filters.txt
more unknown-domains.txt | grep -v ! >>combined-filters.txt
more videoadex-domains.txt | grep -v ! >>combined-filters.txt
more volumedata-domains.txt | grep -v ! >>combined-filters.txt

more combined-filters.txt | grep -v :::::::::::::: | grep -v .txt >>temp-filters.txt
mv -f temp-filters.txt combined-filters.txt

perl ../scripts/addChecksum.pl combined-filters.txt
perl ../scripts/sorter.pl combined-filters.txt
