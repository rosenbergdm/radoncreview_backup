#!/usr/bin/env bash

LOGFILE=/var/log/radoncreview_dump_constraints.log
SCRIPTFILE=$($READLINK -f $0)
SCRIPTDIR="$(dirname $SCRIPTFILE)"
PAGE_DB="/Volumes/LaptopBackup2/RadOncReviewBackups"
tmplogfile="$(mktemp -t ror.con.dp)"
SOURCE_FILE="$SCRIPTDIR/../constraint_urls.txt"




function cleanup() {
  rm -f "${tmplogfile:-NOTEMPLOGFILE}"
}
trap cleanup EXIT

export_file() {
  local uid="$1"
  local fname="$2"
  gs-to-csv "$uid" "Sheet1" .
  echo mv Sheet1.csv "$PAGE_DB/${fname}.csv"
  mv Sheet1.csv "$PAGE_DB/${fname}.csv"
}

main() {
  while IFS="" read -r line || [[ -n "$line" ]]; do
    fname="$(echo "$line" | awk '{print $1}')"
    uid="$(echo "$line" | awk '{print $3}')"
    export_file "$uid" "$fname"
  done < "$SOURCE_FILE"
}

main >$LOGFILE 2>&1

