#! /bin/csh -f

set datestamp = `/bin/date '+%Y%m%d-%H%M%S'`
set base = /dash/apps/dash
set harvestbase = /dash/apps/dash-harvester

cd ${harvestbase}

# harvest dash_ucb
echo "Harvesting dash_ucb: `/bin/date '+%Y%m%d-%H%M%S'`"
/dash/local/bin/python ${harvestbase}/parseFeed14.py \
	"https://merritt.cdlib.org/object/recent.atom?collection=ark:/13030/m5q82t8x" \
	ucb

# harvest dash_uci:
echo "Harvesting dash_uci: `/bin/date '+%Y%m%d-%H%M%S'`"
/dash/local/bin/python ${harvestbase}/parseFeed14.py \
	"https://merritt.cdlib.org/object/recent.atom?collection=ark:/13030/m5fr19qh" \
	uci

# harvest dash_ucla
 echo "Harvesting dash_ucla: `/bin/date '+%Y%m%d-%H%M%S'`"
 /dash/local/bin/python ${harvestbase}/parseFeed14.py \
       "https://merritt.cdlib.org/object/recent.atom?collection=ark:/13030/m5tm8r6v" \
       ucla    
	
# harvest dash_ucm:
echo "Harvesting dash_ucm: `/bin/date '+%Y%m%d-%H%M%S'`"
/dash/local/bin/python ${harvestbase}/parseFeed14.py \
"https://merritt.cdlib.org/object/recent.atom?collection=ark:/13030/m5b00k0h" \
ucm

# harvest ucm_ssczo
echo "Harvesting ucm_ssczo: `/bin/date '+%Y%m%d-%H%M%S'`"
/dash/local/bin/python ${harvestbase}/parseFeed14.py \
"https://merritt.cdlib.org/object/recent.atom?collection=ark:/13030/m5sv2b3c" \
ucm

# harvest dash_ucr:
echo "Harvesting dash_ucr: `/bin/date '+%Y%m%d-%H%M%S'`"
/dash/local/bin/python ${harvestbase}/parseFeed14.py \
	"https://merritt.cdlib.org/object/recent.atom?collection=ark:/13030/m5jt2v2m" \
	ucr

# harvest dash_ucsb:
#echo "Harvesting dash_ucsb: `/bin/date '+%Y%m%d-%H%M%S'`"
#/dash/local/bin/python ${harvestbase}/parseFeed14.py \
#	"https://merritt-stage.cdlib.org/object/recent.atom?collection=ark:/13030/m5xs78k8" \
#	ucsb

# harvest dash_ucsc:
echo "Harvesting dash_ucsc: `/bin/date '+%Y%m%d-%H%M%S'`"
/dash/local/bin/python ${harvestbase}/parseFeed14.py \
	"https://merritt.cdlib.org/object/recent.atom?collection=ark:/13030/m5t16hvv" \
	ucsc

# harvest datashare_ucsf:
# closed collection--no need to harvest 
#echo "Harvesting datashare_ucsf: `/bin/date '+%Y%m%d-%H%M%S'`"
#/dash/local/bin/python ${harvestbase}/parseFeed14.py \
#	"https://merritt.cdlib.org/object/recent.atom?collection=ark:/13030/m5ng4nz1" \
#       ucsf

# harvest datashare_ucsf_lib:
echo "Harvesting datashare_ucsf_lib: `/bin/date '+%Y%m%d-%H%M%S'`"
/dash/local/bin/python ${harvestbase}/parseFeed14.py \
       "https://merritt.cdlib.org/object/recent.atom?collection=ark:/13030/m52j8gvj" \
       ucsf

# harvest dash_cdl
echo "Harvesting dash_cdl: `/bin/date '+%Y%m%d-%H%M%S'`"
/dash/local/bin/python ${harvestbase}/parseFeed14.py \
        "https://merritt.cdlib.org/object/recent.atom?collection=ark:/13030/m5v13jxb" \
        ucop

# harvest dataone_dash
echo "Harvesting dataone_dash: `/bin/date '+%Y%m%d-%H%M%S'`"
/dash/local/bin/python ${harvestbase}/parseFeed14.py \
      "https://merritt.cdlib.org/object/recent.atom?collection=ark:/13030/m5709fmd" \
        dataone

# harvest dataup_dash
# Dataup Dash objects contain only mrt-eml.xml files, not mrt-datacite.xml
# parseFeed script needs to be modified for it to harvest these files
#echo "Harvesting dataup_dash: `/bin/date '+%Y%m%d-%H%M%S'`"
#/dash/local/bin/python ${harvestbase}/parseFeed14.py \
#      "https://merritt.cdlib.org/object/recent.atom?collection=ark:/13030/m5222s39" \
#        dataup


echo "Incremental indexing of XTF: `/bin/date '+%Y%m%d-%H%M%S'`"
cd ${base}
/bin/csh -f ${base}/index.csh

exit 0
