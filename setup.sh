#!/bin/bash
set -e

# ============================================================
# setup.sh - Automated setup for wsl-assistant on Debian in WSL2
# ============================================================
# NOTE: This script is intended to be run inside your Debian
# instance in WSL2. Ensure systemd is enabled in your WSL2
# configuration (see /etc/wsl.conf) before running.
# ============================================================

echo "===================================="
echo "Starting wsl-assistant setup..."
echo "===================================="

# Update and upgrade system packages
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# ----------------------------------------
# 1. Install Essential Packages
# ----------------------------------------
echo "Installing essential packages..."
sudo apt install -y curl wget ufw fail2ban unattended-upgrades openssh-server git cmake ninja-build python3-venv python3-pip nodejs npm

echo "Node.js version: $(node --version)"
echo "npm version: $(npm --version)"

# ----------------------------------------
# 2. Install Redis Stack Server
# ----------------------------------------
echo "Installing Redis Stack Server..."
sudo apt-get install -y lsb-release curl gpg
curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
sudo chmod 644 /usr/share/keyrings/redis-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb jammy main" | sudo tee /etc/apt/sources.list.d/redis.list
sudo apt update
sudo apt install -y redis-stack-server
sudo systemctl enable redis-stack-server
sudo systemctl start redis-stack-server

if redis-cli ping | grep -q "PONG"; then
    echo "✅ Redis Stack Server is running."
else
    echo "❌ Error: Redis Stack Server did not start correctly."
fi

# ----------------------------------------
# 3. Install Neo4j
# ----------------------------------------
echo "Installing Oracle JDK 21 for Neo4j..."
wget https://download.oracle.com/java/21/latest/jdk-21_linux-x64_bin.deb -O /tmp/jdk-21_linux-x64_bin.deb
sudo dpkg -i /tmp/jdk-21_linux-x64_bin.deb || sudo apt-get install -f -y
echo "Java version: $(java --version)"

echo "Installing Neo4j..."
wget -O - https://debian.neo4j.com/neotechnology.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/neotechnology.gpg
echo 'deb [signed-by=/etc/apt/keyrings/neotechnology.gpg] https://debian.neo4j.com stable latest' | sudo tee /etc/apt/sources.list.d/neo4j.list
sudo apt-get update
sudo apt-get install -y neo4j=1:2025.02.0

echo "Setting initial password for Neo4j..."
sudo neo4j-admin dbms set-initial-password password

NEO4J_CONF="/etc/neo4j/neo4j.conf"
if grep -q "# server.default_listen_address=0.0.0.0" "$NEO4J_CONF"; then
    echo "Updating Neo4j network settings..."
    sudo sed -i 's|# server.default_listen_address=0.0.0.0|server.default_listen_address=0.0.0.0|' "$NEO4J_CONF"
fi

sudo systemctl enable neo4j
sudo systemctl start neo4j

if neo4j status | grep -q "is running"; then
    echo "✅ Neo4j is running."
else
    echo "❌ Error: Neo4j did not start correctly."
fi

# ----------------------------------------
# 4. Install llama.cpp and AI Models
# ----------------------------------------
echo "Installing llama.cpp dependencies and building the project..."
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

echo "Setting up Python environment for model conversion..."
cd $HOME
if [ ! -d "SmolLM2-360M-Instruct" ]; then
    GIT_LFS_SKIP_SMUDGE=1 git clone https://huggingface.co/HuggingFaceTB/SmolLM2-360M-Instruct
fi
mkdir models
python3 -m venv ~/llama-cpp-venv
source ~/llama-cpp-venv/bin/activate
python -m pip install --upgrade pip wheel setuptools
python -m pip install --upgrade -r $HOME/llama.cpp/requirements/requirements-convert_hf_to_gguf.txt

echo "Converting and quantizing model..."
python $HOME/llama.cpp/convert_hf_to_gguf.py SmolLM2-360M-Instruct --outfile $HOME/models/SmolLM2.gguf
llama-quantize $HOME/models/SmolLM2.gguf $HOME/models/SmolLM2.q8.gguf Q8_0 4
deactivate

# ----------------------------------------
# 5. Create systemd service for llama-server
# ----------------------------------------
echo "Creating systemd service for llama-server..."
sudo tee /etc/systemd/system/llama-server.service > /dev/null <<EOF
[Unit]
Description=llama-server Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/llama-server -m \$HOME/models/SmolLM2.q8.gguf --host 0.0.0.0
Restart=on-abnormal
RestartSec=3
User=$USER
WorkingDirectory=\$HOME
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=llama-server

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable llama-server
sudo systemctl start llama-server

if systemctl is-active --quiet llama-server; then
    echo "✅ llama-server service is running."
else
    echo "❌ Error: llama-server service did not start."
fi

# ----------------------------------------
# 6. Configure Auto-Restart for Redis and Neo4j
# ----------------------------------------
echo "Configuring auto-restart for Redis and Neo4j..."
sudo sed -i '/^\[Service\]/a Restart=on-abnormal\nRestartSec=5' /lib/systemd/system/neo4j.service
sudo sed -i '/^\[Service\]/a Restart=on-abnormal\nRestartSec=5' /lib/systemd/system/redis-stack-server.service
sudo systemctl daemon-reload

# ----------------------------------------
# 7. Secure the Server
# ----------------------------------------
echo "Securing the server..."
sudo sed -i 's/^#*PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo systemctl restart ssh

echo "Configuring UFW..."
sudo ufw allow ssh
sudo ufw allow 6379/tcp    # Redis
sudo ufw allow 7474/tcp    # Neo4j
sudo ufw allow 8080/tcp    # llama.cpp (assumed port)
sudo ufw --force enable

echo "Enabling unattended-upgrades..."
sudo apt purge -y unattended-upgrades
sudo apt install -y unattended-upgrades
sudo tee /etc/apt/apt.conf.d/50unattended-upgrades > /dev/null <<EOF
Unattended-Upgrade::Origins-Pattern {
  "origin=Debian,codename=\${distro_codename},label=Debian";
  "origin=Debian,codename=\${distro_codename},label=Debian-Security";
  "origin=Debian,codename=\${distro_codename}-security,label=Debian-Security";
};
EOF
sudo systemctl enable unattended-upgrades

echo "Installing and configuring Fail2Ban..."
sudo apt install -y fail2ban
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo systemctl restart fail2ban

# ----------------------------------------
# 8. Make Redis Persistent
# ----------------------------------------
echo "Configuring Redis persistence..."
echo "save 900 1" | sudo tee -a /etc/redis-stack.conf
sudo systemctl restart redis-stack-server

# ----------------------------------------
# 9. Finalize Setup
# ----------------------------------------
echo "===================================="
echo "Setup complete. Please verify all services are running."
echo "You may wish to reboot your WSL2 instance for all changes to take full effect."
echo "===================================="
