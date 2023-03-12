#!/opt/homebrew/bin/bash
#
# dump_pages.sh
# Copyright (C) 2020 David Rosenberg <dmr@davidrosenberg.me>
# Exports the listed google docs pages to a specified directory in 
#   multiple formats.  Suitable for use as a cron job
# Distributed under terms of the MIT license.
#
# Usage: dump_pages.sh [-vhq] [--debug] [--logfile=LOGFILE] [--source=SOURCE_FILE]
#        dump_pages.sh [-vhq] [--debug] [--logfile=LOGFILE] --format=FORMAT --target=TARGETFILE URL
#
#
#
# Arguments:
#   FILE                     Url to download and dump a single page from (for example, 
#                             https://docs.google.com/document/d/1-mwiAYV0BZnxdSKLIgU19wofB3p-YqtPOUtPFg5AFMs/edit)
#   
# Options:
#   -h --help                display usage
#   -v --verbose             verbose mode
#   -q --quiet               quiet mode
#   --debug                  debug this script
#   --logfile=LOGFILE        log output to this file [default: /var/log/radoncreview_dump_pages.log]
#   --format=FORMAT          format to dump page to either docx or pdf [default: docx]
#   --target=TARGETFILE      file to write the output dumped page to
#   --source=SOURCE_FILE     List of urls and corresponding names to download en masse [default: ./source_files.txt]
#

error_count=0
source "$(which docopts.sh)" --auto "$@"

[[ ${ARGS[--debug]} == true ]] && docopt_print_ARGS
if [[ "${ARGS[--verbose]}" == true ]]; then
  DEBUG_SCRIPT=${DEBUG_SCRIPT:-1}
fi

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
SCRIPTFILE=$($READLINK -f "$0")
SCRIPTDIR="$(dirname "$SCRIPTFILE")"
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

# function unzip_docx() {
#   local srcfile tgtdir
#   srcfile="$(greadlink -f "${1}")"
#   tgtdir="${srcfile//.docx/_docx}"
#   if [ -d "$tgtdir" ]; then
#     rm -r "$tgtdir"
#   fi
#   mkdir -p "$tgtdir"
#   pushd "$tgtdir"
#   unzip "$srcfile"
#   popd
# }

function export_file() {
  local format="${3:-doc}"
  local srcfile="${1//edit*/export?format=$format}"
  if [ "$format" == "doc" ]; then
    format=docx
  fi
  local tgtfile="$2.$format"
  echo "$WGET" -q "$srcfile" -O "$tgtfile"
  $WGET "$srcfile" -O "$tgtfile"
}

function script_main() {
  datedir="$PAGE_DB/$(date +%Y-%m-%d)"
  mkdir "$datedir" 2> /dev/null || echo "Directory $datedir already exists"
  while IFS="" read -r line || [[ -n "$line" ]]; do
    if echo "$line" | grep -v '^\s*#' > /dev/null; then
      for fmt in "${FORMATS[@]}"; do
        local iserror
        iserror=0
        srcfile=$(echo "$line" | cut -f1 -d \|)
        tgtfile="$datedir/$(echo "$line" | cut -f2 -d \|)"
        [[ ${ARGS[--debug]} == true ]] && printf "Downloading %s to %s\n" "$srcfile" "$tgtfile"
        if export_file "$srcfile" "$tgtfile" "$fmt" > "$tmplogfile" 2>&1;  then
          printf "$(date): '%s' backed up to '%s.%s' successfully\n" "$srcfile" "$tgtfile" "$fmt" | tee -a $LOGFILE
        else
          ((iserror+=1)) 
        fi
        if [ $iserror -eq 1 ]; then
          ((error_count+=1))
          printf "$(date): '%s' FAILED to be backed up to '%s.%s'\n" "$srcfile" "$tgtfile" "$fmt" | tee -a $LOGFILE
        fi
      done
    fi
  done < <( sed '/^\s*$/d' < "$SOURCE_FILE" )
}


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
