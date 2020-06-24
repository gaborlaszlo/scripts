#!/bin/bash
# Parse a csv and output processed content based on definitions:
# in_definition: ';' separated list of csv field names, no spaces
#	example: name;phone;birthday
# defaults:	 bash variable definition style overrides or defaults for inputs
# 	example: name="${name:-John Doe}" # default
#		 birthday=1970-01-01 # override
# out_definition: bash code that evaluates to desired output
# 	example: [ "$(date +%M-%D)" = "${birthday#*-}" ] && sendsms -n "$phone" --text "Happy birthday, dear $name!"

USAGE="$0 -i IN_FILE -o OUT_FILE [-p PREFIX]
Where PREFIX is the path to the definition files: defaults in_definition out_definition (defaults to .)"
AUTHOR='gabor.laszlo@ieee.org'
LINE='---------------------------'
MY_IFS=';'

[ $DEBUG ] && DEBUG_LOG=$(mktemp) && set -x
LOG_FILE="/var/tmp/${0##*/}.log"
log(){
	echo -e "$*" | tee -a "$LOG_FILE" $DEBUG_LOG
}
die(){
	status=$1
	shift
	log "Status $status: $*\n$LINE"
	exit $status
}

# Parse commandline
PARM="$*"
while	getopts ":i:o:p:" Option
do	case $Option in
i)	IN_FILE="$OPTARG";;
o)	OUT_FILE="$OPTARG";;
p)	PREFIX="$OPTARG";;
*)	echo -e "$USAGE"
	exit 0;;
esac
done
shift $((OPTIND - 1))

# Check inputs
[ -f "$IN_FILE" ] || die 1 "No IN_FILE: $IN_FILE !"
[ -z "$OUT_FILE" ] && OUT_FILE="${IN_FILE%.*}.out"
DIR="${PREFIX:-.}"
[ -d "$DIR" ] || die 1 "$DIR not a directory!"

for	i in defaults in_definition out_definition
do	eval $i="$DIR/$i"
	[ -f "${!i}" ] || die 1 "No $i file found in $DIR!"
done
head -1 "$in_definition"| grep ' ' && die 1 "Space found in in_definition. Please fix definition files."

# Do the work
log "$(date '+%F %T') - $PWD - $0 $PARM"
dos2unix "$IN_FILE"
log $(wc -l "$IN_FILE")
rm -f "$OUT_FILE"
while	IFS="$MY_IFS" read -r $(head -1 "$in_definition"| tr "$MY_IFS" ' ')
do	. "$defaults"
	eval "echo -e \"$(egrep -v '^#' $out_definition)\""
done < "$IN_FILE" >> "$OUT_FILE"
die 0 "Finished: $(wc -l $OUT_FILE)"
