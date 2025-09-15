#!/bin/bash
# OpenCode AI + Ollama server installation script for Ubuntu using npm

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

# Install nvm if not present
if ! command -v nvm &> /dev/null; then
  echo "Installing nvm (Node Version Manager)..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
else
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
fi

# Install latest LTS Node.js and npm using nvm
echo "Installing Node.js using nvm..."
nvm install --lts
nvm use --lts

echo "Installing OpenCode CLI globally with npm..."
npm install -g opencode-ai

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

OPENCODE_PATH=$(command -v opencode || true)
if [[ -z "$OPENCODE_PATH" ]]; then
  echo "ERROR: OpenCode binary not found after npm install."
  echo "Check npm logs or your PATH environment."
  exit 1
fi

echo "Starting OpenCode AI server using $OPENCODE_PATH ..."
"$OPENCODE_PATH" serve --hostname 0.0.0.0 --port 4096

echo "Setup complete!"
echo "You can now connect from any client using: opencode tui --server http://<server-ip>:4096"
