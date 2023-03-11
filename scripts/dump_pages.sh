#! /usr/local/bin/bash
#
# dump_pages.sh
# Copyright (C) 2020 David Rosenberg <dmr@davidrosenberg.me>
# Exports the listed google docs pages to a specified directory in 
#   multiple formats.  Suitable for use as a cron job
# Distributed under terms of the MIT license.
#

if [ -x /usr/local/bin/greadlink ]; then
  READLINK=/usr/local/bin/greadlink
else
  READLINK=$(which readlink)
fi
if [ -x /usr/local/bin/wget ]; then
  WGET=/usr/local/bin/wget
else
  WGET=$(which wget)
fi
LOGFILE=/var/log/radoncreview_dump_pages.log
SCRIPTFILE=$($READLINK -f $0)
SCRIPTDIR="$(dirname $SCRIPTFILE)"
# PAGE_DB="/Volumes/LaptopBackup2/RadOncReviewBackups"
PAGE_DB=/opt/ror/backups
tmplogfile="$(mktemp -t ror.dp)"
SOURCE_FILE="$SCRIPTDIR/../source_files.txt"
# FORMATS=( doc )
FORMATS=( doc pdf )




function cleanup() {
  rm -f "${tmplogfile:-NOTEMPLOGFILE}"
}
trap cleanup EXIT

function unzip_docx() {
  local srcfile="$(greadlink -f "${1}")"
  local tgtdir="${srcfile//.docx/_docx}"
  if [ -d "$tgtdir" ]; then
    rm -r "$tgtdir"
  fi
  mkdir -p "$tgtdir"
  pushd "$tgtdir"
  unzip "$srcfile"
  popd
}

function export_file() {
  local format="${3:-doc}"
  local srcfile="${1//edit*/export?format=$format}"
  if [ "$format" == "doc" ]; then
    format=docx
  fi
  local tgtfile="$2.$format"
  echo $WGET -q "$srcfile" -O "$tgtfile"
  $WGET -q "$srcfile" -O "$tgtfile"
}

function script_main() {
  datedir="$PAGE_DB/$(date +%Y-%m-%d)"
  mkdir "$datedir" 2> /dev/null || echo "Directory $datedir already exists"
  while IFS="" read -r line || [[ -n "$line" ]]; do
    if $(echo $line | grep -v '^\s*#' > /dev/null); then
      for fmt in "${FORMATS[@]}"; do
        local iserror=0
        srcfile=$(echo $line | cut -f1 -d \|)
        tgtfile="$datedir/$(echo $line | cut -f2 -d \|)"
        echo "downloading $srcfile to $tgtfile"
        export_file "$srcfile" "$tgtfile" "$fmt" 2>&1 > "$tmplogfile" && \
          echo -e "$(date): '$srcfile' backed up to '$tgtfile.$fmt' successfully'" | tee -a $LOGFILE || \
          ((iserror+=1)) 
        if [ $iserror -eq 1 ]; then
          ((error_count+=1))
          echo -e "$(date): '$srcfile' FAILED to back up to '$tgtfile.$fmt'" | tee -a $LOGFILE
        fi
      done
    fi
  done < <( cat "$SOURCE_FILE" | sed '/^\s*$/d')
}

usage() {
  echo "USAGE: $0"
  echo "  Using the list of files in $SOURCE_FILE, backup all gdocs files"
  #TODO: Better documentation
}

if [[ "$1" == "-h" ]] || [[ "$1" = "-help" ]] || [[ "$1" == "--help" ]]; then
  usage
  exit 255
fi

error_count=0
script_main
if [ $error_count -eq 0 ]; then
  echo "$(date): All files backed up successfully" | tee -a $LOGFILE
  trap - EXIT
  cleanup
  exit 0
else
  echo "$(date): Not all files backed up successfully, see log at $tmplogfile" | tee -a $LOGFILE
  echo "error_count = $error_count"
  trap - EXIT
  exit $error_count
fi


# vim: ft=sh
