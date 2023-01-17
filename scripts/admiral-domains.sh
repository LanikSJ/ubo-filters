#!/usr/bin/env bash

date=$(date +%Y%m%d)
olddate=$(cat filters/getadmiral-domains.txt |grep "Last modified" |awk '{print $4}')

cd filters
../scripts/remove-lines.sh getadmiral-domains.txt 15 > getadmiral-domains-temp.txt && mv getadmiral-domains-temp.txt getadmiral-domains.txt
curl -L https://raw.githubusercontent.com/jkrejcha/AdmiraList/master/AdmiraList.txt |sed -e 's/^/||/' -e 's/$/^/' | sort -d >> getadmiral-domains.txt
sed -i "s/$olddate/"$date"01/g" getadmiral-domains.txt
perl ../scripts/addChecksum.pl getadmiral-domains.txt
perl ../scripts/sorter.pl getadmiral-domains.txt
