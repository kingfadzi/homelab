#!/usr/bin/env bash
set -euo pipefail

# 🖥️ Tuned runtime variables
export OLLAMA_NUM_THREADS=8
export OLLAMA_NUM_PARALLEL=1
export OLLAMA_NUM_GPU=0
export OLLAMA_KEEP_ALIVE=20m
unset OLLAMA_CONTEXT_LENGTH
export OLLAMA_MODELS="${HOME}/.ollama/models"
export OLLAMA_HOST="0.0.0.0:11434"
export OLLAMA_DEBUG=INFO

PID_FILE="${HOME}/.ollama/ollama.pid"
LOG_FILE="${HOME}/.ollama/ollama.log"
OLLAMA_BIN="/usr/local/bin/ollama"

start_ollama() {
  if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "Ollama already running (PID $(cat "$PID_FILE"))."
    exit 0
  fi
  echo "Starting Ollama..."
  mkdir -p "$(dirname "$LOG_FILE")"
  nohup "$OLLAMA_BIN" serve >"$LOG_FILE" 2>&1 &
  echo $! > "$PID_FILE"
  echo "Ollama started with PID $(cat "$PID_FILE"). Logs: $LOG_FILE"
}

stop_ollama() {
  if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "Stopping Ollama (PID $(cat "$PID_FILE"))..."
    kill "$(cat "$PID_FILE")"
    rm -f "$PID_FILE"
    echo "Ollama stopped."
  else
    echo "Ollama is not running."
  fi
}

restart_ollama() {
  stop_ollama || true
  sleep 1
  start_ollama
}

logs_ollama() {
  if [[ -f "$LOG_FILE" ]]; then
    echo "Tailing Ollama logs (Ctrl+C to stop)..."
    tail -f "$LOG_FILE"
  else
    echo "No log file found at $LOG_FILE"
  fi
}

case "${1:-}" in
  start)   start_ollama ;;
  stop)    stop_ollama ;;
  restart) restart_ollama ;;
  status)
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      echo "Ollama is running (PID $(cat "$PID_FILE"))."
    else
      echo "Ollama is not running."
    fi
    ;;
  logs)    logs_ollama ;;
  *)
    echo "Usage: $0 {start|stop|restart|status|logs}"
    exit 1
    ;;
esac
