#!/bin/bash

set -e

trap "trap_ctrlc" 2


APPLICATION_ID="edge-to-cloud"
EDGE_APP_NAME="edge-to-cloud"
EDGE_APP="edge-to-cloud.tar.gz"
EDGE_APP_CONFIG="edge-to-cloud-config.zip"
EDGE_SERVICES_ID="predix-edge-services"
EDGE_SERVICES_CONFIG="predix-services-config.zip"
EDGE_SERVICES="predix-services.tar.gz"
ROOT_DIR=$(pwd)

if [[ $(docker service ls -f "name=$APPLICATION_ID_$EDGE_APP_NAME" -q | wc -l) -gt 0 ]]; then
  docker service rm "$APPLICATION_ID_$EDGE_APP_NAME"
  echo "Edge Application $EDGE_APP_NAME service removed"
fi

mkdir -p /var/lib/edge-agent/app/$EDGE_SERVICES_ID/conf/
rm -rf /var/lib/edge-agent/app/$EDGE_SERVICES_ID/conf/*
unzip /mnt/data/downloads/$EDGE_SERVICES_CONFIG -d /var/lib/edge-agent/app/$EDGE_SERVICES_ID/conf/

if [[ ! -e /var/run/edge-agent/access-token/access_token ]]; then
  cd /var/run/edge-agent/access-token
  cp /mnt/data/downloads/access_token .
  cd /mnt/data/downloads
fi

/opt/edge-agent/app-deploy --enable-core-api $EDGE_SERVICES_ID /mnt/data/downloads/$EDGE_SERVICES

/opt/edge-agent/app-deploy --enable-core-api $APPLICATION_ID /mnt/data/downloads/$EDGE_APP

if [[ $(docker service ls -f "name=$APPLICATION_ID_$EDGE_APP_NAME" -q | wc -l) > 0 ]]; then
  echo "Edge Application $EDGE_APP_NAME service started"
fi

docker service logs $(docker service ls -f "name=$APPLICATION_ID_$EDGE_APP_NAME" -q)

docker service ls
