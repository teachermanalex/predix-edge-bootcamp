#!/bin/bash

set -e

trap "trap_ctrlc" 2


APPLICATION_ID="my-edge-app"
EDGE_APP_NAME="$1"
EDGE_APP="my-edge-app.tar.gz"
EDGE_APP_CONFIG="my-edge-app-config.zip"

ROOT_DIR=$(pwd)

if [[ $(docker service ls -f "name=$APPLICATION_ID_$EDGE_APP_NAME" -q | wc -l) > 0 ]]; then
  docker service rm "$APPLICATION_ID_$EDGE_APP_NAME"
  echo "Edge Application $EDGE_APP_NAME service removed"
fi

curl http://localhost/api/v1/applications --unix-socket /var/run/edge-core/edge-core.sock -X POST -F "file=@/mnt/data/downloads/$EDGE_APP" -H "app_name: $APPLICATION_ID"

mkdir -p /var/lib/edge-agent/app/$APPLICATION_ID/conf/
rm -rf /var/lib/edge-agent/app/$APPLICATION_ID/conf/*
unzip /mnt/data/downloads/$EDGE_APP_CONFIG -d /var/lib/edge-agent/app/$APPLICATION_ID/conf/
cp /mnt/data/downloads/access_token /var/run/edge-agent/access_token/
/opt/edge-agent/app-start --appInstanceId=$APPLICATION_ID

sleep 20

if [[ $(docker service ls -f "name=$APPLICATION_ID_$EDGE_APP_NAME" -q | wc -l) > 0 ]]; then
  echo "Edge Application $EDGE_APP_NAME service started"
fi

docker service logs $(docker service ls -f "name=$APPLICATION_ID_$EDGE_APP_NAME" -q)
