#!/usr/bin/env bash

READLINK=$(which greadlink)
DIRNAME=$(which gdirnamne)
PRINTF=$(which gprintf)
LOGFILE=/var/log/radoncreview_dump_constraints.log
SCRIPTFILE=$($READLINK -f "$0")
SCRIPTDIR="$(dirname "$SCRIPTFILE")"
# PAGE_DB="/Volumes/LaptopBackup2/RadOncReviewBackups"
BACKUP_DIR=/opt/ror/backups
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
  echo mv Sheet1.csv "$BACKUP_DIR/${fname}.csv"
  mv Sheet1.csv "$BACKUP_DIR/${fname}.csv"
}

main() {
  while IFS="" read -r line || [[ -n $line ]]; do
    fname="$(echo "$line" | awk '{print $1}')"
    uid="$(echo "$line" | awk '{print $3}')"
    $PRINTF "*********************\n%s\n" "Exporting $fname from $uid"
    export_file "$uid" "$fname"
    sleep 10
  done <"$SOURCE_FILE"
}

prepare_backup() {
  # Sanity checks, etc.
  # TODO
  mkdir -p "$(dirname "$LOGFILE")"
  touch "$LOGFILE" || $PRINTF "****ERROR: Logfile not writable, aborting*****" 
  mkdir -p "$BACKUP_DIR"


}

prepare_backup
main >>$LOGFILE 2>&1
