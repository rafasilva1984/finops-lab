#!/bin/bash

# ============================================
# FinOps – Seed de histórico MASSIVO
# Gera dezenas de milhares de documentos
# no índice finops-efficiency
# ============================================

ES_URL="${ES_URL:-http://localhost:9200}"
INDEX="${ES_INDEX:-finops-efficiency}"

echo ">> Iniciando seed massivo no índice [$INDEX] em [$ES_URL] ..."

# Quantidade de histórico e densidade
HOURS_BACK=168         # 7 dias (24*7)
SAMPLES_PER_HOUR=60    # 60 amostras/hora por instância

INSTANCES=(
  "app01:9100"
  "app02:9100"
  "app03:9100"
  "payments01:9100"
  "payments02:9100"
  "auth01:9100"
  "db01:9100"
  "db02:9100"
)

SERVICES=(
  "checkout-api"
  "payments-api"
  "auth-service"
  "reporting-job"
  "batch-billing"
  "notification-worker"
)

OWNERS=(
  "squad-checkout"
  "squad-payments"
  "squad-auth"
  "platform-team"
  "data-eng"
)

ENVS=(
  "prod"
  "staging"
)

TMP_BULK="/tmp/finops_bulk.ndjson"
> "$TMP_BULK"
DOC_COUNT=0

echo ">> Garantindo índice com mapeamento básico..."

curl -k -s -X PUT "$ES_URL/$INDEX" -H 'Content-Type: application/json' -d '{
  "mappings": {
    "properties": {
      "@timestamp": { "type": "date" },
      "instance":   { "type": "keyword" },
      "service":    { "type": "keyword" },
      "owner":      { "type": "keyword" },
      "env":        { "type": "keyword" },
      "cpu_percent":   { "type": "float" },
      "mem_percent":   { "type": "float" },
      "net_mbps":      { "type": "float" },
      "disk_MBps":     { "type": "float" },
      "disk_iops":     { "type": "float" },
      "source":        { "type": "keyword" }
    }
  }
}' > /dev/null

echo ">> Gerando dados de $HOURS_BACK horas atrás até agora..."
for h in $(seq 0 $HOURS_BACK); do
  # Tenta data -d (GNU); se não rolar (fallback), usa agora
  TS=$(date -u -Iseconds -d "$h hours ago" 2>/dev/null || date -u -Iseconds)

  for inst in "${INSTANCES[@]}"; do
    for s in $(seq 1 $SAMPLES_PER_HOUR); do

      svc_index=$((RANDOM % ${#SERVICES[@]}))
      owner_index=$((RANDOM % ${#OWNERS[@]}))
      env_index=$((RANDOM % ${#ENVS[@]}))

      service="${SERVICES[$svc_index]}"
      owner="${OWNERS[$owner_index]}"
      env="${ENVS[$env_index]}"

      # Métricas "realistas"
      cpu=$((20 + RANDOM % 70))          # 20–89 %
      mem=$((40 + RANDOM % 50))          # 40–89 %
      net=$((RANDOM % 50))               # 0–49 Mbps
      disk_mb=$((RANDOM % 80))           # 0–79 MB/s
      disk_iops=$((50 + RANDOM % 950))   # 50–999 IOPS

      # staging menos carregado
      if [ "$env" = "staging" ]; then
        cpu=$((cpu / 2))
        net=$((net / 2))
        disk_mb=$((disk_mb / 2))
        disk_iops=$((disk_iops / 2))
      fi

      cat >> "$TMP_BULK" <<EOF
{"index":{"_index":"$INDEX"}}
{"@timestamp":"$TS","instance":"$inst","cpu_percent":$cpu,"mem_percent":$mem,"net_mbps":$net,"disk_MBps":$disk_mb,"disk_iops":$disk_iops,"service":"$service","owner":"$owner","env":"$env","source":"finops_seed_history"}
EOF

      DOC_COUNT=$((DOC_COUNT + 1))

      if (( DOC_COUNT % 5000 == 0 )); then
        echo ">> Enviando lote... (total até agora: $DOC_COUNT docs)"
        curl -k -s -H 'Content-Type: application/x-ndjson' -X POST "$ES_URL/_bulk" --data-binary @"$TMP_BULK" > /dev/null
        > "$TMP_BULK"
      fi
    done
  done
done

if [ -s "$TMP_BULK" ]; then
  echo ">> Enviando último lote... (total final: $DOC_COUNT docs)"
  curl -k -s -H 'Content-Type: application/x-ndjson' -X POST "$ES_URL/_bulk" --data-binary @"$TMP_BULK" > /dev/null
fi

echo ">> Seed concluído. Total de documentos enviados: $DOC_COUNT"
echo ">> Agora você tem um histórico bem parrudo para os dashboards."
