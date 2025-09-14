#!/bin/bash
# OpenCode AI + Ollama server installation script for Ubuntu using absolute path

set -e

echo "Updating and installing prerequisites..."
sudo apt update && sudo apt upgrade -y
sudo apt install curl git wget build-essential -y

echo "Installing Ollama model provider..."
curl -fsSL https://ollama.com/install.sh | sh
sudo systemctl enable ollama
sudo systemctl start ollama

echo "Pulling Coding Models with Ollama..."
ollama pull codellama
ollama pull starcoder2

echo "Installing OpenCode CLI server..."
curl -fsSL https://opencode.ai/install | bash

echo "Preparing OpenCode configuration..."
mkdir -p ~/.config/opencode
cat <<EOF > ~/.config/opencode/config.yaml
providers:
  - name: local-codellama
    type: ollama
    apiBase: http://localhost:11434/
    model: codellama
  - name: local-starcoder2
    type: ollama
    apiBase: http://localhost:11434/
    model: starcoder2
EOF

OPENCODE_PATH="$HOME/.local/bin/opencode"
if [[ ! -x "$OPENCODE_PATH" ]]; then
  echo "ERROR: OpenCode binary not found at $OPENCODE_PATH."
  echo "Try installing globally with 'npm install -g opencode-ai' or check install logs."
  exit 1
fi

echo "Starting OpenCode AI server using $OPENCODE_PATH ..."
"$OPENCODE_PATH" serve --hostname 0.0.0.0 --port 4096

echo "Setup complete!"
echo "You can now connect from any client using: opencode tui --server http://<server-ip>:4096"
