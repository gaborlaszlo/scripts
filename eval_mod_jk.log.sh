#!/bin/bash
sed 's/.*\]//; s/ [0-9\.]*$//' mod_jk.log| sort |uniq -c | sort -nr| head
