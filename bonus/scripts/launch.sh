k3d cluster create --config bonus/confs/k3d-config.yaml

if [ $(cat /etc/hosts | grep gitlab | wc -l) -eq 0 ]
then
    echo 127.0.0.1 gitlab.bonus.com | sudo tee -a /etc/hosts > /dev/null
fi
