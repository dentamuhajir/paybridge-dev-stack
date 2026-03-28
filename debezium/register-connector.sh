#!/bin/bash
set -e

DEBEZIUM_URL=${DEBEZIUM_URL:-http://localhost:8085}
CONNECTOR_FILE="$(dirname "$0")/connectors/outbox-connector.json"

# Load env variables
if [ -f "$(dirname "$0")/../debezium/debezium.env" ]; then
  export $(cat "$(dirname "$0")/../debezium/debezium.env" | grep -v '^#' | xargs)
fi

echo "Waiting for Debezium to be ready..."
until curl -s "$DEBEZIUM_URL/connectors" > /dev/null 2>&1; do
  sleep 2
done
echo "Debezium is ready!"

# Cek apakah connector sudah ada
EXISTING=$(curl -s "$DEBEZIUM_URL/connectors/paybridge-outbox-connector" | grep -c "paybridge-outbox-connector" || true)

if [ "$EXISTING" -gt 0 ]; then
  echo "Connector already exists, deleting first..."
  curl -s -X DELETE "$DEBEZIUM_URL/connectors/paybridge-outbox-connector"
  sleep 2
fi

# Replace env variables di JSON dan register
echo "Registering connector..."
CONFIG=$(cat "$CONNECTOR_FILE" \
  | sed "s/\${DB_USER}/$DB_USER/g" \
  | sed "s/\${DB_PASSWORD}/$DB_PASSWORD/g" \
  | sed "s/\${DB_NAME}/$DB_NAME/g")

curl -s -X POST "$DEBEZIUM_URL/connectors" \
  -H "Content-Type: application/json" \
  -d "$CONFIG"

echo ""
echo "Connector registered!"

# Verifikasi status
sleep 3
echo "Connector status:"
curl -s "$DEBEZIUM_URL/connectors/paybridge-outbox-connector/status" | python3 -m json.tool