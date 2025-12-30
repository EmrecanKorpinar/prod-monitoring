#!/bin/bash

ALLOWED=(22 80 443)
OPEN=$(ss -tuln | grep LISTEN | awk '{print $5}' | awk -F: '{print $NF}')

for port in $OPEN; do
  if [[ ! " ${ALLOWED[@]} " =~ " $port " ]]; then
    echo "$(date): UNAUTHORIZED PORT $port" >> data/security.log
  fi
done
