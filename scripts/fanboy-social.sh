#!/usr/bin/env bash

cd filters || exit
curl -L https://easylist.to/easylist/fanboy-social.txt |grep -Ev '##|#@' > fanboy-social-no-cosmetic.txt
perl ../scripts/addChecksum.pl fanboy-social-no-cosmetic.txt
perl ../scripts/sorter.pl fanboy-social-no-cosmetic.txt