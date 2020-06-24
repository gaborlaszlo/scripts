#!/bin/bash
FN=${HOSTNAME//\./_}-access_log
FILE_IN=${1:-$FN}
[ -f "$FILE_IN" ] || exit 1
LIST_HOSTS=(
'192.168.194.20'
)
LIST_IDS=(
'cid=M[0-9]*[|%]'
'imageId='
'height='
'width='
'fid='
'gid=gid:\/\/de.css.hr.pzm.abwesenheit.Abwesenheitszeit\/\/'
'gid=gid%3A%2F%2Fde.css.hr.pzm.abwesenheit.Abwesenheitszeit%2F%2F'
)
for	((i=0; i<${#LIST_HOSTS[@]}; i++))
do	FILTER_HOSTS="$FILTER_HOSTS${FILTER_HOSTS:+|}^${LIST_HOSTS[i]}"
done
for	((i=0; i<${#LIST_IDS[@]}; i++))
do	FILTER_IDS="$FILTER_IDS${FILTER_IDS:+; }s/\\([\\&\\?]${LIST_IDS[i]}\\).*\\([\\& ]\\)/\\1XXX\\2/"
done
grep -Ev "$FILTER_HOSTS" "$FILE_IN"| \
sed 's/.*\]//; s/ [0-9\.]*$//; s/ -$//'| \
sed "$FILTER_IDS"| \
sort |uniq -c | sort -nr
