#!/bin/bash

CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print 100- $8}')
MEM=$(free | awk '/Mem/ {printf("%.2f"), $3/2 *100}')
DISK=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
TIME=$(date + "%Y-%m-%d %H: %M:%S")

echo "$TIME,$CPU,$MEM,$DISK" >> data/metrics.csv
