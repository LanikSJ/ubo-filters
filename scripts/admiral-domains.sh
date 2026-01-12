#!/usr/bin/env bash

cd filters || exit
../scripts/remove-lines.sh getadmiral-domains.txt 15 >getadmiral-domains-temp.txt && mv getadmiral-domains-temp.txt getadmiral-domains.txt
curl -L https://raw.githubusercontent.com/LanikSJ/AdmiraList/master/AdmiraList.txt | sed -e 's/^/||/' -e 's/$/^/' | sort -d >>getadmiral-domains.txt
perl ../scripts/addChecksum.pl getadmiral-domains.txt
