#!/bin/bash

# ============================================
# FinOps – Ingestão em tempo real
# Gera documentos continuamente para o índice
# finops-efficiency (Ctrl+C para parar)
# ============================================

ES_URL="${ES_URL:-http://localhost:9200}"
INDEX="${ES_INDEX:-finops-efficiency}"

echo ">> Ingestão em tempo real iniciada em [$ES_URL/$INDEX]"
echo ">> Use CTRL+C para parar."

INSTANCES=(
  "app01:9100"
  "app02:9100"
  "payments01:9100"
  "auth01:9100"
  "db01:9100"
)

SERVICES=(
  "checkout-api"
  "payments-api"
  "auth-service"
  "reporting-job"
)

OWNERS=(
  "squad-checkout"
  "squad-payments"
  "squad-auth"
  "platform-team"
)

ENVS=(
  "prod"
  "staging"
)

while true; do
  TS=$(date -u -Iseconds)

  for inst in "${INSTANCES[@]}"; do
    svc_index=$((RANDOM % ${#SERVICES[@]}))
    owner_index=$((RANDOM % ${#OWNERS[@]}))
    env_index=$((RANDOM % ${#ENVS[@]}))

    service="${SERVICES[$svc_index]}"
    owner="${OWNERS[$owner_index]}"
    env="${ENVS[$env_index]}"

    # Métricas com leve variação "ao vivo"
    cpu=$((30 + RANDOM % 60))          # 30–89
    mem=$((50 + RANDOM % 40))          # 50–89
    net=$((RANDOM % 30))               # 0–29 Mbps
    disk_mb=$((RANDOM % 60))           # 0–59 MB/s
    disk_iops=$((100 + RANDOM % 900))  # 100–999

    if [ "$env" = "staging" ]; then
      cpu=$((cpu / 2))
      net=$((net / 2))
      disk_mb=$((disk_mb / 2))
      disk_iops=$((disk_iops / 2))
    fi

    curl -k -s -X POST "$ES_URL/$INDEX/_doc" \
      -H 'Content-Type: application/json' \
      -d "{
        \"@timestamp\": \"$TS\",
        \"instance\": \"$inst\",
        \"cpu_percent\": $cpu,
        \"mem_percent\": $mem,
        \"net_mbps\": $net,
        \"disk_MBps\": $disk_mb,
        \"disk_iops\": $disk_iops,
        \"service\": \"$service\",
        \"owner\": \"$owner\",
        \"env\": \"$env\",
        \"source\": \"finops_realtime_script\"
      }" > /dev/null
  done

  echo \"[$TS] Enviadas métricas em tempo real para ${#INSTANCES[@]} instâncias...\"
  sleep 5
done
