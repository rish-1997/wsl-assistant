#!/bin/bash
# start.sh - Start all core services for wsl-assistant

echo "===================================="
echo "Starting WSL Assistant services..."
echo "===================================="

# --- Redis Stack Server ---
echo "[1/3] Starting Redis Stack Server..."
sudo systemctl start redis-stack-server
# Give Redis a moment to start up
sleep 2
if redis-cli ping | grep -q "PONG"; then
    echo "✅ Redis Stack Server is running."
else
    echo "❌ Error: Redis Stack Server failed to start."
fi

# --- Neo4j ---
echo "[2/3] Starting Neo4j..."
sudo systemctl start neo4j
# Allow some time for Neo4j to initialize
sleep 5
neo4j_status=$(neo4j status)
if echo "$neo4j_status" | grep -q "is running"; then
    echo "✅ Neo4j is running."
else
    echo "❌ Error: Neo4j failed to start."
fi

# --- llama-server ---
echo "[3/3] Starting llama-server..."
# Check if llama-server is already running
if curl -s -X GET http://localhost:8080/health | grep -q '"status":"ok"'; then
    echo "✅ llama-server is already running."
else
    # Launch llama-server in the background. Adjust the model path if needed.
    llama-server -m SmolLM2.q8.gguf &
    sleep 2
    if pgrep -x "llama-server" > /dev/null; then
        echo "✅ llama-server started successfully."
    else
        echo "❌ Error: llama-server failed to start."
    fi
fi

echo "===================================="
echo "All services have been initiated."
echo "===================================="

