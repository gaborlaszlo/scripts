#!/bin/bash
cat "${HOSTNAME//\./_}-error_log"| sed 's/.*\]//'|sort |uniq -c | sort -nr
