#!/bin/bash
set -e  # Arrête le script à la première erreur

ROLE=$1
SERVER_IP=$2
K3S_TOKEN=$3

echo ">>> Préparation de la machine en cours..."

echo ">>> Mise à jour des paquets et installation des dépendances (iptables, kmod)..."
sudo apt-get update -y
sudo apt-get install -y iptables kmod

if [ "$ROLE" == "server" ]; then
    echo ">>> [ijaberS] Installation de K3s en mode server..."

    curl -sfL https://get.k3s.io | \
      INSTALL_K3S_EXEC="server \
        --flannel-iface eth1 \
        --write-kubeconfig-mode 644" \
        K3S_TOKEN="${K3S_TOKEN}" \
      sh -

    echo ">>> [ijaberS] K3s server démarré."
    echo ">>> [ijaberS] Attente que le nœud soit Ready..."
    
    until sudo kubectl get nodes 2>/dev/null | grep -q "Ready"; do
      sleep 3
    done
    
    echo ">>> [ijaberS] Nœud prêt !"

elif [ "$ROLE" == "agent" ]; then
    echo ">>> [ijaberSW] Installation de K3s en mode agent..."

    curl -sfL https://get.k3s.io | \
      K3S_URL="https://${SERVER_IP}:6443" \
      K3S_TOKEN="${K3S_TOKEN}" \
      sh -

    echo ">>> [ijaberSW] Agent K3s démarré et connecté à ijaberS."

else
    echo "Erreur : Rôle non reconnu ($ROLE)."
    exit 1
fi