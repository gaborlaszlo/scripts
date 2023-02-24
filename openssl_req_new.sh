#!/bin/bash
# USAGE: $0 [-c configfile] CNAME [alias [alias]]
# e.g. $0 campus-bgbau-test.ms.bgnet.de
[ "$1" = '-c' ] && shift && config=$1 && shift
[ ! -f "$config" ] && echo "$config not found" && exit 1

CN=${CN:-$1}
while	[ -z "$CN" ]
do	read -p 'CN=' CN
done
[ -n "$2" ] && shift && for a in $@; do ALT="$ALT, DNS:$a"; done

[ -z "$config" ] && for	i in *.cfg
do	c=${i%.cfg}
	[ "$CN" != "${CN%$c}" ] && config=$i
done
if	[ -z "$config" ]
then	echo "no matching config file found, you'll have to do it by hand."
else	sed "s/_CN_/$CN/g" $config > temp.cfg
	[ -n "$ALT" ] && sed -i "s/\(.*DNS:.*\)/\1$ALT/" temp.cfg
	cat temp.cfg
fi

echo "generate Private Key"
openssl genrsa -des3 -out $CN.enc.key 2048
echo "decrypt Key"
openssl rsa -in $CN.enc.key -out $CN.key -outform PEM

echo "create Cert request"
openssl req -new -key $CN.key -sha256 -out $CN.csr ${config:+-config temp.cfg}

echo "inspect Cert request:"
openssl req -noout -text -in $CN.csr
