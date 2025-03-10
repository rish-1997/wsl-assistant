#!/bin/bash
set -e

# Detect if running in WSL
VIRT=$(systemd-detect-virt 2>/dev/null || echo "none")
if [[ "$VIRT" != "wsl" ]]; then
    echo "Running in non WSL environment (non-systemd mode)."
    
    # Update system packages
    echo "Updating system packages..."
    sudo apt update && sudo apt upgrade -y

    # Install essential packages
    echo "Installing essential packages..."
    sudo apt install -y curl wget ufw fail2ban git cmake ninja-build python3-venv python3-pip nodejs npm

    # Install Redis Stack Server
    echo "Installing Redis Stack Server..."
    sudo apt-get install -y lsb-release curl gpg
    curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
    sudo chmod 644 /usr/share/keyrings/redis-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb jammy main" | sudo tee /etc/apt/sources.list.d/redis.list
    sudo apt update
    sudo apt install -y redis-stack-server

    # Start Redis manually
    nohup redis-server > redis.log 2>&1 &
    sleep 3
    if redis-cli ping | grep -q "PONG"; then
        echo "✅ Redis Stack Server is running."
    else
        echo "❌ Error: Redis Stack Server did not start correctly."
        exit 1
    fi

    # Install and Start Neo4j
    wget https://download.oracle.com/java/21/latest/jdk-21_linux-x64_bin.deb -O /tmp/jdk-21_linux-x64_bin.deb
    sudo dpkg -i /tmp/jdk-21_linux-x64_bin.deb || sudo apt-get install -f -y
    echo "Java version: $(java --version)"
    echo "Installing Neo4j..."
    wget -O - https://debian.neo4j.com/neotechnology.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/neotechnology.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/neotechnology.gpg] https://debian.neo4j.com stable latest' | sudo tee /etc/apt/sources.list.d/neo4j.list
    sudo apt-get update
    sudo apt-get install -y neo4j=1:2025.02.0
    sudo neo4j-admin dbms set-initial-password password

    nohup neo4j console > neo4j.log 2>&1 &
    sleep 10
    if neo4j status | grep -q "is running"; then
        echo "✅ Neo4j is running."
    else
        echo "❌ Error: Neo4j did not start correctly."
        exit 1
    fi

    # Install and Start llama-server
    echo "Installing llama.cpp..."
    cd $HOME
    if [ ! -d "llama.cpp" ]; then
        git clone https://github.com/ggml-org/llama.cpp.git
    fi
    cd llama.cpp
    git submodule update --init --recursive

    cmake -S . -B build -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DLLAMA_BUILD_TESTS=OFF \
      -DLLAMA_BUILD_EXAMPLES=ON \
      -DLLAMA_BUILD_SERVER=ON \
      -DBUILD_SHARED_LIBS=OFF

    cmake --build build --config Release -j $(nproc)
    sudo cmake --install build --config Release
    
    echo "Installing Git LFS for model download..."
    cd $HOME
    curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | sudo bash
    sudo apt-get install git-lfs

    if [ ! -d "SmolLM2-360M-Instruct" ]; then
        echo "Cloning SmolLM2-360M-Instruct model repository..."
        git clone https://huggingface.co/HuggingFaceTB/SmolLM2-360M-Instruct
        cd SmolLM2-360M-Instruct
        git lfs install
        git lfs pull
    else
        echo "SmolLM2-360M-Instruct model repository already exists."
    fi

    echo "Setting up Python environment for model conversion..."
    cd $HOME
    mkdir models
    python3 -m venv ~/llama-cpp-venv
    source ~/llama-cpp-venv/bin/activate
    python -m pip install --upgrade pip wheel setuptools
    python -m pip install --upgrade -r $HOME/llama.cpp/requirements/requirements-convert_hf_to_gguf.txt

    echo "Converting and quantizing model..."
    python $HOME/llama.cpp/convert_hf_to_gguf.py SmolLM2-360M-Instruct --outfile $HOME/models/SmolLM2.gguf
    llama-quantize $HOME/models/SmolLM2.gguf $HOME/models/SmolLM2.q8.gguf Q8_0 4
    deactivate


    nohup llama-server -m \$HOME/models/SmolLM2.q8.gguf > llama-server.log 2>&1 &
    sleep 5
    if curl -s -X GET http://localhost:8080/health | grep -q '"status":"ok"'; then
        echo "✅ llama-server is healthy."
    else
        echo "❌ Error: llama-server health check failed."
        exit 1
    fi
    
    echo "✅ All services started successfully in WSL environment."
else
    echo "Running in WSL environment. Falling back to setup.sh"
    ./setup.sh
fi
