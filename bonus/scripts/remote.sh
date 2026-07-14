#!/bin/sh

PASSWORD=$(kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -o jsonpath='{.data.password}' | base64 -d)
git remote add gitlab http://root:$PASSWORD@gitlab.bonus.com/root/iot.git
