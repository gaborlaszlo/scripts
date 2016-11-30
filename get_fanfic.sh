#!/bin/bash
# Pulls chapters of fic with given ID from faniction.net
USAGE="$0 FIC_ID [chapter]"

get_chapter(){
	chapter=$1
	curl -o raw.$chapter.html $base_url/$chapter && echo "Downloaded Chapter $chapter"
	echo "<!DOCTYPE html><html><head><meta charset='utf-8'>" > $chapter.html
	grep '<title>' raw.$chapter.html >> $chapter.html
	echo '</head><body>' >> $chapter.html
	grep "id='storytext'" raw.$chapter.html | sed "s/<div class='storytext.*id='storytext'>//" >> $chapter.html
	echo '</body></html>' >> $chapter.html
	rm raw.$chapter.html
}
if	[ "$1" = '-h' ]
then	echo -e "$USAGE"
	exit
fi
[ -z "$@" ] && read -p "Fic_ID: " FIC_ID
FIC_ID=${1:-$FIC_ID}
shift

mkdir $FIC_ID
cd ./$FIC_ID
base_url="https://www.fanfiction.net/s/$FIC_ID/"
curl -o lastpage.html $base_url
[ $? -gt 0 ] && echo "ERROR" && exit

if	[ -n "$2" ]
then	get_chapter $2
else	for	ch in $(grep 'id=chap_select' lastpage.html| tr ' ' '\n'| grep 'value='| sed 's/value=//'| sort -un)
	do	get_chapter $ch
	done
fi
rm lastpage.html
