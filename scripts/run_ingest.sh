#!/bin/bash

# ============================================
# FinOps – Ingestão massiva de dados de exemplo
# Gera milhares de documentos no índice finops-efficiency
# ============================================

# URL do Elasticsearch (pode sobrescrever com ES_URL se quiser)
ES_URL="${ES_URL:-http://localhost:9200}"
INDEX="${ES_INDEX:-finops-efficiency}"

echo ">> Iniciando ingestão massiva no índice [$INDEX] em [$ES_URL] ..."

# --------------------------------------------
# Conjunto de instâncias simuladas
# --------------------------------------------
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

# Serviços e donos (owners) simulados
SERVICES=(
  "checkout-api"
  "payments-api"
  "auth-service"
  "reporting-job"
  "batch-billing"
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

# --------------------------------------------
# Parâmetros da simulação
# --------------------------------------------
HOURS_BACK=48        # quantas horas para trás (48h de histórico)
SAMPLES_PER_HOUR=12  # quantas amostras por hora por instância

TMP_BULK="/tmp/finops_bulk.ndjson"
> "$TMP_BULK"

DOC_COUNT=0

# Garante que o índice existe com mapeamento básico (opcional)
echo ">> Criando índice (se não existir)..."
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

# --------------------------------------------
# Loop principal de geração dos documentos
# --------------------------------------------

for h in $(seq 0 $HOURS_BACK); do
  # Timestamp "h horas atrás"
  # Git Bash normalmente aceita o -d
  TS=$(date -u -Iseconds -d "$h hours ago" 2>/dev/null || date -u -Iseconds)

  for inst in "${INSTANCES[@]}"; do
    for s in $(seq 1 $SAMPLES_PER_HOUR); do

      # Escolhe serviço / owner / env pseudo-aleatórios
      svc_index=$((RANDOM % ${#SERVICES[@]}))
      owner_index=$((RANDOM % ${#OWNERS[@]}))
      env_index=$((RANDOM % ${#ENVS[@]}))

      service="${SERVICES[$svc_index]}"
      owner="${OWNERS[$owner_index]}"
      env="${ENVS[$env_index]}"

      # Métricas "realistas" (bem aproximadas, mas boas pra gráfico)
      cpu=$((RANDOM % 90))                    # 0–89 %
      mem=$((40 + RANDOM % 50))               # 40–89 %
      net=$((RANDOM % 20))                    # 0–19 Mbps
      disk_mb=$((RANDOM % 50))                # 0–49 MB/s
      disk_iops=$((50 + RANDOM % 450))        # 50–499 IOPS

      # Pequena diferenciação por ambiente
      if [ "$env" = "staging" ]; then
        cpu=$((cpu / 2))
        net=$((net / 2))
        disk_mb=$((disk_mb / 2))
        disk_iops=$((disk_iops / 2))
      fi

      # Linha de ação do bulk
      cat >> "$TMP_BULK" <<EOF
{"index":{"_index":"$INDEX"}}
{"@timestamp":"$TS","instance":"$inst","cpu_percent":$cpu,"mem_percent":$mem,"net_mbps":$net,"disk_MBps":$disk_mb,"disk_iops":$disk_iops,"service":"$service","owner":"$owner","env":"$env","source":"finops_bulk_script"}
EOF

      DOC_COUNT=$((DOC_COUNT + 1))

      # Envia em lotes de 1000 documentos
      if (( DOC_COUNT % 1000 == 0 )); then
        echo ">> Enviando lote... (total até agora: $DOC_COUNT docs)"
        curl -k -s -H 'Content-Type: application/x-ndjson' -X POST "$ES_URL/_bulk" --data-binary @"$TMP_BULK" > /dev/null
        > "$TMP_BULK"
      fi

    done
  done
done

# Envia o resto (se sobrou algo)
if [ -s "$TMP_BULK" ]; then
  echo ">> Enviando último lote... (total final: $DOC_COUNT docs)"
  curl -k -s -H 'Content-Type: application/x-ndjson' -X POST "$ES_URL/_bulk" --data-binary @"$TMP_BULK" > /dev/null
fi

echo ">> Ingestão concluída. Total de documentos enviados: $DOC_COUNT"
echo ">> Agora seus dashboards do Kibana têm dados suficientes para brincar à vontade. :)"
