#!/bin/bash
set -e

echo "Installing Docker..."
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker ubuntu

echo "Installing Ollama..."
curl -fsSL https://ollama.com/install.sh | sh

echo "Waiting for Ollama service to start..."
sleep 10

echo "Pulling llama3.1:8b model..."
ollama pull llama3.1:8b

echo "Done!"