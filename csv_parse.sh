#!/bin/bash
# Parse a csv and output processed content based on definitions
USAGE="$0 -i IN_FILE -o OUT_FILE [-p PREFIX]
Where PREFIX is the path to the definition files: defaults, in.definition, out.definition"
AUTHOR='gabor.laszlo@wirecard.com'

[ $DEBUG ] && DEBUG_LOG=$(mktemp) && set -x
LOG_FILE=/var/tmp/${0##*/}.log
log(){
	echo -e "$@" | tee -a $LOG_FILE $DEBUG_LOG
}
die(){
	log "Status $1: $2\n$LINE"
	[ $DEBUG ] || rm $DEBUG_LOG
	exit $1
}

# Parse commandline
PARM="$*"
while	getopts ":i:o:p:" Option
do	case $Option in
i)	IN_FILE=$OPTARG;;
o)	OUT_FILE=$OPTARG;;
p)	PREFIX=$OPTARG;;
*)	echo -e "$USAGE"
	exit 0;;
esac
done
shift $(($OPTIND - 1))
[ -z "$OUT_FILE" ] && OUT_FILE=${IN_FILE%.*}.out

for	i in defaults in_definition out_definition
do	eval $i=${PREFIX:-.}/$i
	[ -f "${!i}" ] || die 1 "No $i file found in ${PREFIX:-.}!"
done
[ -f "$IN_FILE" ] || die 1 "No IN_FILE: $IN_FILE !"
dos2unix $IN_FILE
wc -l $IN_FILE
rm -f $OUT_FILE

. $defaults
while	IFS=';' read -r $(< $in_definition)
do	eval "echo \"$(< $out_definition)\""
done < $IN_FILE >> $OUT_FILE
wc -l $OUT_FILE
