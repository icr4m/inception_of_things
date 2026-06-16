#!/bin/bash
set -e

ROLE="$1"
SERVER_IP="$2"
K3S_TOKEN="$3"

echo "---- Update apt packages ----"
apt-get update -y
apt-get install -y curl wget git vim net-tools openssh-client

if [ "$ROLE" == "server" ]; then
  echo "---- Installing K3s server ----"

  IFACE=$(ip -o -4 addr show | awk "/$(echo $SERVER_IP | sed 's/\./\\./g')/ {print \$2}")

  curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
    --node-ip=${SERVER_IP} \
    --bind-address=${SERVER_IP} \
    --advertise-address=${SERVER_IP} \
    --flannel-iface=${IFACE} \
    --disable=traefik \
    --disable=metrics-server \
    --disable=servicelb" sh -

  echo "---- Waiting for node-token ----"
  while [ ! -f /var/lib/rancher/k3s/server/node-token ]; do
    sleep 1
  done

  echo "---- Waiting for K3s to be ready ----"
  until kubectl get nodes 2>/dev/null | grep -q "Ready"; do
    sleep 2
  done

  echo "---- K3s server ready ----"
  kubectl get nodes

elif [ "$ROLE" == "agent" ]; then
  echo "---- Installing K3s agent ----"

  IFACE=$(ip -o -4 addr show | awk "/$(echo $WORKER_IP | sed 's/\./\\./g')/ {print \$2}")

  # Attendre que le serveur K3s soit joignable
  echo "---- Waiting for K3s API server at ${SERVER_IP}:6443 ----"
  until curl -sk https://${SERVER_IP}:6443/ping | grep -q "ok" 2>/dev/null; do
    echo "  API not ready yet..."
    sleep 3
  done

  # Récupérer le token directement depuis le server via SSH
  echo "---- Fetching token from server ----"
  TOKEN=""
  while [ -z "$TOKEN" ]; do
    TOKEN=$(ssh -o StrictHostKeyChecking=no \
                -o ConnectTimeout=5 \
                -o BatchMode=yes \
                -i /home/vagrant/.ssh/id_ed25519 \
                vagrant@${SERVER_IP} \
                "sudo cat /var/lib/rancher/k3s/server/node-token 2>/dev/null") || true
    if [ -z "$TOKEN" ]; then
      echo "  Token not available yet, retrying..."
      sleep 3
    fi
  done

  echo "---- Token retrieved, joining cluster ----"

  curl -sfL https://get.k3s.io | \
    K3S_URL="https://${SERVER_IP}:6443" \
    K3S_TOKEN="${TOKEN}" \
    INSTALL_K3S_EXEC="agent \
      --node-ip=${WORKER_IP} \
      --flannel-iface=${IFACE}" sh -

  echo "---- K3s agent installed ----"

else
  echo "ERROR: Unknown role '$ROLE'. Use 'server' or 'agent'."
  exit 1
fi