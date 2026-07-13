#!/bin/bash
set -e

ROLE="$1"
SERVER_IP="$2"

# Récupération automatique de l'IP locale (utile pour l'agent ou le serveur)
LOCAL_IP=$(hostname -I | awk '{print $1}')

echo "=== [1/3] Mise à niveau du système et outils requis ==="
apt-get update -y
apt-get install -y curl wget git vim net-tools openssh-client

if [ "$ROLE" == "server" ]; then
  echo "=== [2/3] Initialisation du nœud Maître (K3s Server) ==="

  # Identification de l'interface réseau associée à l'IP du serveur
  IFACE=$(ip -o -4 addr show | awk "/$(echo $SERVER_IP | sed 's/\./\\./g')/ {print \$2}")

  curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
    --node-ip=${SERVER_IP} \
    --bind-address=${SERVER_IP} \
    --advertise-address=${SERVER_IP} \
    --flannel-iface=${IFACE} \
    --disable=traefik \
    --disable=metrics-server \
    --disable=servicelb" sh -

  echo ">> Génération des clés de sécurité en cours..."
  while [ ! -f /var/lib/rancher/k3s/server/node-token ]; do
    sleep 1
  done

  echo ">> Amorçage du cluster Kubernetes..."
  until kubectl get nodes 2>/dev/null | grep -q "Ready"; do
    sleep 2
  done

  echo "=== [3/3] Déploiement réussi ! Le serveur K3s est opérationnel ==="
  kubectl get nodes

elif [ "$ROLE" == "agent" ]; then
  echo "=== [2/3] Initialisation du nœud de Calcul (K3s Agent) ==="

  # Identification de l'interface réseau locale du worker
  IFACE=$(ip -o -4 addr show | awk "/$(echo $LOCAL_IP | sed 's/\./\\./g')/ {print \$2}")

  echo ">> Liaison réseau : En attente du point d'accès API (${SERVER_IP}:6443)..."
  until curl -sk https://${SERVER_IP}:6443/ping | grep -q "ok" 2>/dev/null; do
    echo "   [Statut] Le serveur principal ne répond pas encore, nouvelle tentative..."
    sleep 3
  done

  echo ">> Connexion SSH sécurisée pour extraire le jeton d'authentification..."
  TOKEN=""
  while [ -z "$TOKEN" ]; do
    TOKEN=$(ssh -o StrictHostKeyChecking=no \
                -o ConnectTimeout=5 \
                -o BatchMode=yes \
                -i /home/vagrant/.ssh/id_ed25519 \
                vagrant@${SERVER_IP} \
                "sudo cat /var/lib/rancher/k3s/server/node-token 2>/dev/null") || true
    if [ -z "$TOKEN" ]; then
      echo "   [Statut] Autorisation en attente sur le serveur, reconnexion..."
      sleep 3
    fi
  done

  echo ">> Jeton validé. Raccordement au cluster central..."

  curl -sfL https://get.k3s.io | \
    K3S_URL="https://${SERVER_IP}:6443" \
    K3S_TOKEN="${TOKEN}" \
    INSTALL_K3S_EXEC="agent \
      --node-ip=${LOCAL_IP} \
      --flannel-iface=${IFACE}" sh -

  echo "=== [3/3] Intégration réussie ! L'agent K3s a rejoint le cluster ==="

else
  echo "Erreur critique : Rôle spécifié '$ROLE' invalide. Options attendues : 'server' ou 'agent'."
  exit 1
fi
