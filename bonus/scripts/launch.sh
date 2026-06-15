#!/bin/sh

REPO_PATH=$(pwd)

k3d cluster create --config bonus/confs/k3d-config.yaml --volume $REPO_PATH/bonus:/app@all

if [ $(cat /etc/hosts | grep gitlab | wc -l) -eq 0 ]
then
    echo 127.0.0.1 gitlab.bonus.com | sudo tee -a /etc/hosts > /dev/null
fi

if [ $(git remote -v | grep gitlab.bonus.com | wc -l) -eq 0 ]
then
    git remote add gitlab git@gitlab.bonus.com:root/iot.git
fi
