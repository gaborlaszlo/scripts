#!/bin/bash
cat mod_jk.log| sed 's/.*\]//; s/ [0-9\.]*$//'| sort |uniq -c | sort -nr| head
