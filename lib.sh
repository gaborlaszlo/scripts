#!/bin/bash
#=======================================================================
# FILE:         lib.sh
#
# USAGE:        . lib.sh
#
# DESCRIPTION:  function library
#
# OPTIONS:      ---
# REQUIREMENTS: See the variable declarations
# BUGS:         None ;)
# NOTES:        Be aware! Changes in this file may
#               change/break things in other scripts.
#               Put only declarative statements here!
#               Sourcing this file should have no sideffects.
#
# AUTHOR:       Gabor Laszlo, gabor.laszlo@ieee.org
AUTHOR_MAIL=gabor.laszlo@ieee.org
# COMPANY:
# VERSION:      1 (testing)
# CREATED:      2014.05.01
# REVISION:
#=======================================================================
[[ $DEBUG ]] && set -x
DEBUG_LOG=$(mktemp)
PARM="$@"
# DOMAIN should be set, e.g. in .bash_profile (dev, test, prod, etc)
DOMAIN=test
# . $HOME/.bash_profile
[[ -z "$DOMAIN" ]] && echo "Cannot determine domain. Exiting" && exit 1

## Variable declarations
# Generic
LINE='##############################################'
SCRIPT=$(ps -h $$| awk '{print $NF}')
SCRIPTNAME=${SCRIPTNAME:-${SCRIPT##*/}}
RECIPIENTS_ERROR=$AUTHOR_MAIL
RECIPIENTS_SUCCESS=$AUTHOR_MAIL
# Directories
DIR_SCRIPT=$(cd ${SCRIPT%/*} && pwd)
DIR_LIB=$DIR_SCRIPT/snippets
DIR_LOG=/var/log/$SCRIPTNAME
# Files
FILE_LOG=$DIR_LOG/${SCRIPTNAME}_$(date +%F_%H%M%S)_$$.log
FILE_PID=/var/run/$SCRIPTNAME.pid

STEP_LOG=
# set this in a snippet before calling die() to attach a file to the postmortem mail.
ATTACH=

## Function definitions
exec 3<&0	# copy stdin before we start messing with pipes.

# log "LEVEL : message"
log(){
	#set +x; D1=$DEBUG; DEBUG=
	# if STEPNAME is set, also log into $DIR_LOG/$STEPNAME/${STEPNAME}...
	if	[ -n "$STEPNAME" ]
	then	mkdir -p $DIR_LOG/$STEPNAME
		STEP_LOG=${STEP_LOG:-$DIR_LOG/$STEPNAME/${STEPNAME}_$(date +%F_%H%M%S)_$$.log}
	else	STEP_LOG=
	fi
	echo -e "$(date +%F_%T) $@" | tee -a $FILE_LOG $STEP_LOG $DEBUG_LOG
	#DEBUG=$D1; D1=; [[ $DEBUG ]] && set -x
}

# die <status> "message"
# mail logs, exit
die(){
	local EXITSTATE="$1"
	shift
	[[ -s "$FILE_PID" ]] && PID="$(<$FILE_PID)"
	if	[[ -z "$PID" ]]
	then	log "WARN : $FILE_PID was empty or missing."
	elif	[[ "$PID" = $$ ]]
	then	rm -f $FILE_PID
	elif	ps -p $PID > /dev/null
	then	log "WARN : I will not remove $FILE_PID from another process. Exiting."
	fi

	log "EXIT $EXITSTATE : $@"
	MSG="Finished $0 $PARM with status ${EXITSTATE/#0/OK}"	# Some people don't know this: http://www.tldp.org/LDP/abs/html/exitcodes.html#EXITCODESREF
	log "INFO : $MSG"
	if	[[ "$EXITSTATE" -ne 0 ]] || grep -q "ERROR" $DEBUG_LOG
	then	cp $DEBUG_LOG $FILE_LOG.debug
		(echo -e "$MSG\n$@\n"; grep "ERROR" $FILE_LOG.debug)| mutt $ATTACH -a $FILE_LOG.debug -s "$DOMAIN ERROR: $0 $PARM" -- $RECIPIENTS_ERROR
	else	echo -e "$MSG\n$@"| mutt $ATTACH -s "$DOMAIN INFO: $0 $PARM" -- $RECIPIENTS_SUCCESS
	fi
	[[ $DEBUG ]] || rm $DEBUG_LOG
	exit $EXITSTATE
}

# setPidFile [PIDfile]
setPidFile(){
	FILE_PID=${1:-$FILE_PID}
	OPTIMISM=60
	while	[ -r $FILE_PID ] && ps -p $(<$FILE_PID) >/dev/null
	do	PID=$(<$FILE_PID)
		log "WARN : $FILE_PID file with PID=$PID found!\n$(ps -p $PID)"
		sleep $OPTIMISM
		OPTIMISM=$(( OPTIMISM + 10 ))
		[ $OPTIMISM -ge 120 ] && die "127" "Giving up: aborted due to another process still running."
	done
	echo $$ > $FILE_PID
}

# ask "prompt"
ask(){
	read -n 1 -p "$@ [Y/n/q] " -u 3	# use original stdin for user interaction
	case "$REPLY" in
	q)	die 0 "Stopped on request";;
	n)	return 1;;
	*)	return 0;;
	esac
}

# check prefix test message
check(){
	for	NAME in $(eval echo \$\{\!${1}\@\})
	do	VALUE=$(eval echo "\${$NAME}")
		if	[ $2 $VALUE ]
		then	log "DEBUG : checked $NAME ($VALUE)"
		else	log "WARN : $NAME ($VALUE) $3"
			ask "Continue?"
		fi
	done
}

# archive file(s)
archive(){
	while [[ ${#@} > 0 ]]
	do	find ${1%/*}/ -maxdepth 1 -type f -name "${1##*/}"| \
		while	read file
		do	[ -f "$file" ] || continue
			mkdir -p ${file%/*}/archive/
			mv -v "$1" ${file%/*}/archive/ 2>/dev/null| tee -a $LOG_FILE
		done
		shift
	done
}

# reject file "message"
# log an error, mail the file and archive it
reject(){
	if	[[ -f "$1" ]]
	then	file="$1"
		shift
	else	file="$FILE_IN"
	fi
	log "INPUT ERROR : $file rejected: $@"
	echo -e "INPUT ERROR : $file rejected: $@"| mutt -s "$DOMAIN REJECT: $0 $PARM" -a "$file" $RECIPIENTS_ERROR
	archive "$file"
	return 1
}

# snippets "prefix"
# source $prefix.*global* and $prefix.*$DOMAIN* files in $PWD
snippets(){
	for	prefix in "$@"
	do	for	snippet in $(find . -name "$prefix*global*" -o -name "$prefix*$DOMAIN*"| sort)
		do	log "INFO : sourcing $snippet"
			if	echo $snippet| grep '.out.'
			then	DEST=${snippet#*.out.}
				DEST=${DEST%%.*}
			fi
			if	[[ $DEBUG ]] && ! ask 'Run?'
			then	return 0
			fi
			. $snippet || return $?
		done
	done
}

# parse_file -s source [-d dest] -a action [filename]
# parse file and run defaults, mapping, override and parse.$SOURCE.$ACTION snippets
parse_file(){
	log "INFO : parse_file $@"
	OPTIND=
	while	getopts ":s:d:a:" Option
	do	case $Option in
	s)	SOURCE=$OPTARG
		IN_DEF=in.$SOURCE.definition
		;;
	d)	local DEST=$OPTARG
		#OUT_DEF=out.$DEST.definition
		;;
	a)	ACTION=$OPTARG
		;;
	*)	FILE_IN=$OPTARG
		;;
	esac
	done
	shift $(($OPTIND - 1))

	egrep -v "^$|^$(head -1 $IN_DEF);" $FILE_IN | \
	while	IFS=';' read -r -a input
	do	snippets defaults || return $?
		index=0
		for	field in $(< $IN_DEF)
		do	snippets mapping.$field || return $?
			snippets override.$field || return $?
			[ -n "${input[$index]}" ] && eval $field=\"${input[$index]}\"
			(( index ++ ))
		done
#		WD_Merchant_ID=$(uuidgen)
		snippets parse.$SOURCE.$ACTION || return $?
		snippets parse.$ACTION || return $?
	done
	DEST=
}

# generate_file -s source [-d dest] [filename]
DIR_PARTNER=$DIR_SCRIPT/partner/$partner
DIR_FILES=$HOME/files/$partner
generate_file(){
	OPTIND=
	while	getopts ":s:d:" Option
	do	case $Option in
	s)	SOURCE=$OPTARG
		IN_DEF=in.$SOURCE.definition
		;;
	d)	local G_DEST=$OPTARG
		#OUT_DEF=out.$DEST.definition
		;;
	*)	FILE_IN=$OPTARG
		;;
	esac
	done
	shift $(($OPTIND - 1))

	parse_file -s $SOURCE ${G_DEST:+-d $G_DEST} -a generate || return $?
	# insert header line if there is HEADER in the out definition
	for	OUT_DEF in $DIR_PARTNER/$SOURCE.out.${G_DEST}*.definition
	do	G_DEST=${OUT_DEF#*.out.}
		G_DEST=${G_DEST%%.*}
		FILE_OUT=$DIR_FILES/$SOURCE.out.$G_DEST/$(eval "echo \"$(head -1 $OUT_DEF)\"")
		if	grep -q '^HEADER' $OUT_DEF
		then	HEADER=$(tail -1 $OUT_DEF| tr -d '$')
			head -1 $FILE_OUT| grep -q "$HEADER" || sed -i "1s/^/$HEADER\n/" $FILE_OUT
		fi
	done
	G_DEST=
}
