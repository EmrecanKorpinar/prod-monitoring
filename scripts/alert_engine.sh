#!/bin/bash

STATE="data/cpu_alert.state"
COOLDOWN=600
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}')
NOW=$(date +%s)

[ ! -f $STATE ] && echo 0 > $STATE
LAST=$(cat $STATE)

if (( $(echo "$CPU > 85" | bc -l) )); then
  if (( NOW - LAST > COOLDOWN )); then
    echo "$(date): CPU ALERT" >> data/alerts.log
    echo $NOW > $STATE
  fi
fi
