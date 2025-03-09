# WSL Assistant 🚀  
*A fully configured local AI & database stack on Debian WSL2.*  

![WSL2](https://img.shields.io/badge/WSL2-Supported-blue)  
![Debian](https://img.shields.io/badge/Debian-Supported-blue)  
![License](https://img.shields.io/badge/License-MIT-green)  


## **1. Table of Contents**
- [1. Table of Contents](#1-table-of-contents)
- [2. Overview](#2-overview)
    - [2.1 Why This Project Exists?](#21-why-this-project-exists)
    - [2.2 Why WSL and Debian?](#22-why-wsl-and-debian)
    - [2.3 What Are the Components and Their Purpose?](#23-what-are-the-components-and-their-purpose)
- [3. Use Cases](#3-use-cases)
- [4. Features](#4-features)
    - [4.1 Security](#41-security)
    - [4.2 Resiliency](#42-resiliency)
    - [4.3 Privacy](#43-privacy)
    - [4.4 Complete E2E RAG](#44-complete-e2e-rag)
- [5. Prerequisites](#5-prerequisites)
- [6. Installation](#6-quickstart-reference)
- [7. Roadmap](#7-roadmap)
- [8. Contributing](#8-contributing)
- [9. License](#9-license)
- [10. Credits](#10-credits)

---

## **2. Overview**  

### **2.1 Why This Project Exists?**  
Developers and AI enthusiasts often struggle with setting up a **reliable, private, and secure local AI assistant**. `WSL Assistant` solves this by providing:  
- **A fully integrated environment** with databases, AI models, and a secure WSL2 setup.  
- **A resilient local inference setup** with Redis for vector storage and Neo4j for knowledge graphs.  
- **Automatic service restart, security hardening, and performance tuning** for WSL2.  

### **2.2 Why WSL and Debian?**  
- **WSL2**: Seamlessly runs Linux on Windows with near-native performance.  
- **Debian**: A stable, secure, and lightweight Linux distribution.  
- **No need for Docker**: Avoids container overhead while still maintaining isolation.  

### **2.3 What Are the Components and Their Purpose?**  
| Component      | Purpose |
|---------------|---------|
| **Redis Stack**  | Fast vector database for storing AI embeddings |
| **Neo4j**       | Graph database for knowledge management |
| **llama.cpp**   | Local AI inference engine |
| **Fail2Ban & UFW** | Security hardening against brute-force attacks |
| **Systemd Auto-Restart** | Ensures services are resilient to crashes |

---

## **3. Use Cases**  
- **AI-powered local search**: Store and retrieve knowledge with Redis + Neo4j.  
- **Self-hosted RAG**: Use `llama.cpp` with vector embeddings for **document Q&A**.  
- **Knowledge graph-powered AI**: Connect ideas with Neo4j and generate insights.  
- **Offline AI assistant**: Run everything locally for **full privacy**.  

---

## **4. Features**  

### **4.1 Security** 🔒  
✅ Disables **root SSH login**  
✅ Enables **firewall (ufw) and Fail2Ban** to prevent attacks  
✅ **Automatic security updates**  

### **4.2 Resiliency** 🔄  
✅ **Auto-restarts essential services** after crashes  
✅ **Persistent Redis storage** for AI embeddings  
✅ WSL2 network and resource optimizations  

### **4.3 Privacy** 🛡️  
✅ No external cloud dependencies  
✅ Local **RAG** setup without sending data to OpenAI / Google  
✅ **Fully air-gapped** if needed  

### **4.4 Complete E2E RAG** 🤖  
✅ Runs **Redis, Neo4j, and `llama.cpp`** together  
✅ Supports **AI-powered document search & retrieval**  
✅ Easily extendable with **LangChain / custom pipelines**  

---

## **5. Prerequisites**  
- **Windows 10/11 with WSL2** enabled  
- **At least 4GB RAM** (8GB recommended for AI inference with >1b parameter models)  
- **At least 20GB free disk space**  

---

## **6. Installation**  

```sh
# Install WSL2 and Debian
wsl --install -d Debian

# Clone this repo
git clone https://github.com/rajatasusual/wsl-assistant.git
cd wsl-assistant

# Run setup script
./setup.sh
```

For **detailed setup instructions**, see [INSTALLATION.md](INSTALLATION.md).  
For **frequently seen issues**, see [FAQs.md](FAQs.md)

## **start.sh**  

```sh
# Start all required services
./start.sh
```

This script starts Redis Stack, Neo4j, and required services in the correct order. It:
- Verifies service dependencies
- Initializes Redis with vector support
- Starts Neo4j graph database
- Configures network settings
- Enables service auto-restart

For troubleshooting, see logs in `/var/log/wsl-assistant/`.

---

## **7. Roadmap** 🚀  
- [ ] Web UI for monitoring services  
- [ ] Dockerized version for portability  
- [ ] Integration with **LangChain** for extended RAG  
- [ ] Multi-user SSH with isolated environments  

---

## **8. Contributing**  
Contributions are welcome! Please:  
1. Fork the repository  
2. Create a new branch (`feature-xyz`)  
3. Submit a **pull request**  

---

## **9. License**  
This project is licensed under the **MIT License**.  

---

## **10. Credits**  
Shout-out to:  
- **[llama.cpp](https://github.com/ggml-org/llama.cpp)** for local AI inference  
- **[Redis](https://redis.io/)** for vector storage  
- **[Neo4j](https://neo4j.com/)** for knowledge graphs  
- **The WSL Community** for making Linux on Windows seamless  
