#!/bin/bash
set -e

echo "Installing SSM Agent..."
sudo snap install amazon-ssm-agent --classic || true
sudo snap start amazon-ssm-agent

echo "Ensuring SSH server allows agent/TCP forwarding for jump host..."
sudo sed -i 's/^#AllowTcpForwarding.*/AllowTcpForwarding yes/' /etc/ssh/sshd_config
sudo systemctl restart ssh

echo "Installing Docker..."
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker ubuntu

echo "Installing AWS CLI..."
sudo apt update
sudo apt install -y unzip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install

echo "Setting up Flowise systemd service..."
sudo cp /tmp/flowise.service /etc/systemd/system/flowise.service
sudo systemctl daemon-reload
sudo systemctl enable flowise.service