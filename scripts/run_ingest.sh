#!/bin/bash
for i in {1..10}; do
  curl -k -X POST http://localhost:9200/finops-efficiency/_doc -H 'Content-Type: application/json' -d '{
    "@timestamp": "'$(date -Iseconds)'",
    "instance": "node-exporter:9100",
    "cpu_percent": 0.3,
    "mem_percent": 40.5,
    "net_mbps": 0.002,
    "disk_MBps": 0.04,
    "disk_iops": 4,
    "service": "core-metrics",
    "owner": "platform-team",
    "env": "prod"
  }'
done
