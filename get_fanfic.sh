#!/bin/bash
# Pulls chapters of fic with given ID from faniction.net
USAGE="$0 FIC_ID [chapter]"

get_chapter(){
	chapter=$1
	curl -o "raw.$chapter.html" "$base_url/$chapter" && echo "Downloaded Chapter $chapter" >&2
	echo "<!DOCTYPE html><html><head><meta charset='utf-8'>"
	grep '<title>' "raw.$chapter.html"
	echo "</head><body>"
	grep "id='storytext'" "raw.$chapter.html" | sed "s/<div class='storytext.*id='storytext'>//"
	echo "</body></html>"
	rm "raw.$chapter.html"
}
if	[ "$1" = '-h' ]
then	echo -e "$USAGE"
	exit
fi
[ -z "$*" ] && read -rp "Fic_ID: " FIC_ID
FIC_ID=${1:-$FIC_ID}
shift

mkdir "$FIC_ID"
cd ./"$FIC_ID" || exit 1
base_url="https://www.fanfiction.net/s/$FIC_ID/"
curl -o lastpage.html.gz "$base_url" && gunzip lastpage.html.gz
#[ $? -gt 0 ] && echo "ERROR" && exit

if	[ -n "$2" ]
then	get_chapter "$2" > "$2.html"
else	{
	echo "<!DOCTYPE html><html><head><meta charset='utf-8'>"
	grep '<title>' lastpage.html
	echo '</head><body>'
	for	ch in $(grep 'id=chap_select' lastpage.html| tr ' ' '\n'| grep 'value='| sed 's/value=//'| sort -un)
	do	get_chapter "$ch"| grep -Ehv 'head>|<title|body>'
	done
	echo '</body></html>'
	} > "$FIC_ID.html"
fi
rm lastpage.html
