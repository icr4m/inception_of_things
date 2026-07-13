#!/bin/bash
set -e

ROLE="$1"
SERVER_IP="$2"
WORKER_IP="$3"

echo "=== [1/3] Mise à niveau du système et outils requis ==="
apt-get update -y
apt-get install -y curl wget git vim net-tools openssh-client

export K3S_START_TIMEOUT="300s"

# Interface réseau privée Vagrant (toujours eth1 pour le réseau privé créé par VirtualBox)
IFACE="eth1"

if [ "$ROLE" == "server" ]; then
  echo "=== [2/3] Initialisation du nœud Maître (K3s Server) ==="

  curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
    --node-ip=${SERVER_IP} \
    --bind-address=${SERVER_IP} \
    --advertise-address=${SERVER_IP} \
    --tls-san=${SERVER_IP} \
    --flannel-iface=${IFACE} \
    --disable=traefik \
    --disable=metrics-server \
    --disable=servicelb" sh -

  echo ">> Génération des clés de sécurité en cours..."
  while [ ! -f /var/lib/rancher/k3s/server/node-token ]; do
    sleep 1
  done

  sudo cat /var/lib/rancher/k3s/server/node-token > /vagrant/node-token

  echo ">> Amorçage du cluster Kubernetes..."
  until kubectl get nodes 2>/dev/null | grep -q "Ready"; do
    sleep 2
  done

  echo "=== [3/3] Déploiement réussi ! Le serveur K3s est opérationnel ==="
  kubectl get nodes

elif [ "$ROLE" == "agent" ]; then
  echo "=== [2/3] Initialisation du nœud de Calcul (K3s Agent) ==="

  echo ">> Liaison réseau : En attente du point d'accès API (${SERVER_IP}:6443)..."
  until curl -sk https://${SERVER_IP}:6443/ping | grep -q "pong" 2>/dev/null; do
    echo "   [Statut] Le serveur principal ne répond pas encore, nouvelle tentative..."
    sleep 3
  done

  echo ">> Extraction du jeton d'authentification depuis le dossier partagé..."
  TOKEN=""
  while [ -z "$TOKEN" ]; do
    if [ -f /vagrant/node-token ]; then
      TOKEN=$(cat /vagrant/node-token)
    else
      echo "   [Statut] Jeton en attente sur le volume partagé, reconnexion..."
      sleep 3
    fi
  done

  echo ">> Jeton validé. Raccordement au cluster central..."

  curl -sfL https://get.k3s.io | \
    K3S_URL="https://${SERVER_IP}:6443" \
    K3S_TOKEN="${TOKEN}" \
    INSTALL_K3S_EXEC="agent \
      --node-ip=${WORKER_IP} \
      --flannel-iface=${IFACE}" sh -

  echo "=== [3/3] Intégration réussie ! L'agent K3s a rejoint le cluster ==="

else
  echo "Erreur critique : Rôle spécifié '$ROLE' invalide. Options attendues : 'server' ou 'agent'."
  exit 1
fi
