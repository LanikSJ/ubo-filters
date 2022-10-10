#!/usr/bin/env bash

date=$(date +%Y%m%d)
cd filters
cp template.txt combined-filters.txt
sed -i "s/2020032301/"$date"01/g" combined-filters.txt

< adback-domains.txt |grep -v ! |sed '/Adblock/d' >> combined-filters.txt
< adkeeper-domains.txt |grep -v ! |sed '/Adblock/d' >> combined-filters.txt
< admaven-domains.txt |grep -v ! |sed '/Adblock/d' >> combined-filters.txt
< admeasures-domains.txt |grep -v ! |sed '/Adblock/d' >> combined-filters.txt
< bt-contentza-domains.txt |grep -v ! |sed '/Adblock/d' >> combined-filters.txt
< cdn-filter-list.txt |grep -v ! |sed '/Adblock/d' >> combined-filters.txt
< cryptomining-domains.txt |grep -v ! |sed '/Adblock/d' >> combined-filters.txt
< freecounterstat-domains.txt |grep -v ! |sed '/Adblock/d' >> combined-filters.txt
< hilltopads-domains.txt |grep -v ! |sed '/Adblock/d' >> combined-filters.txt
< istripper-domains.txt |grep -v ! |sed '/Adblock/d' >> combined-filters.txt
< kitty-domains.txt |grep -v ! |sed '/Adblock/d' >> combined-filters.txt
< macupload-domains.txt |grep -v ! |sed '/Adblock/d' >> combined-filters.txt
< malware-domains.txt |grep -v ! |sed '/Adblock/d' >> combined-filters.txt
< popads-domains.txt |grep -v ! |sed '/Adblock/d' >> combined-filters.txt
< propellerads-domains.txt |grep -v ! |sed '/Adblock/d' >> combined-filters.txt
< toradvertising-domains.txt |grep -v ! |sed '/Adblock/d' >> combined-filters.txt
< unknown-domains.txt |grep -v ! |sed '/Adblock/d' >> combined-filters.txt
< videoadex-domains.txt |grep -v ! |sed '/Adblock/d' >> combined-filters.txt
< volumedata-domains.txt |grep -v ! |sed '/Adblock/d' >> combined-filters.txt

perl ../scripts/addChecksum.pl combined-filters.txt
perl ../scripts/sorter.pl combined-filters.txt
