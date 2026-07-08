sudo kubectl apply -f ../config/jellyfin/deployement.yaml
sudo kubectl apply -f ../config/jellyfin/service.yaml

sudo kubectl apply -f ../config/plex/deployement.yaml
sudo kubectl apply -f ../config/plex/service.yaml

sudo kubectl apply -f ../config/nginx/deployement.yaml
sudo kubectl apply -f ../config/nginx/service.yaml

sudo kubectl apply -f ../config/ingress.yaml