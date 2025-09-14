#!/bin/bash
# OpenCode AI + Ollama server installation script for Ubuntu
# Installs, configures, checks $PATH, and starts OpenCode server for code models

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

echo "Ensuring ~/.local/bin is in PATH..."
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  echo 'export PATH="$PATH:$HOME/.local/bin"' >> ~/.bashrc
  export PATH="$PATH:$HOME/.local/bin"
fi

echo "Reloading shell configuration..."
source ~/.bashrc

echo "Checking for OpenCode binary in PATH..."
OPENCODE_PATH=$(command -v opencode || true)
if [[ -z "$OPENCODE_PATH" ]]; then
  # Fallback to typical local/bin path
  if [[ -x "$HOME/.local/bin/opencode" ]]; then
    OPENCODE_PATH="$HOME/.local/bin/opencode"
    echo "Using local OpenCode binary: $OPENCODE_PATH"
  elif [[ -x "/usr/local/bin/opencode" ]]; then
    OPENCODE_PATH="/usr/local/bin/opencode"
    echo "Using system OpenCode binary: $OPENCODE_PATH"
  else
    echo "ERROR: 'opencode' command not found in PATH or in expected locations."
    echo "Check installation logs or try installing globally with 'npm install -g opencode-ai' or building from source."
    exit 1
  fi
fi

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

echo "Starting OpenCode AI server..."
"$OPENCODE_PATH" serve --hostname 0.0.0.0 --port 4096

echo "Setup complete!"
echo "You can now connect from any client using: opencode tui --server http://<server-ip>:4096"
