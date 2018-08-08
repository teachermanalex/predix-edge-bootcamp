#!/bin/bash

set -e

trap "trap_ctrlc" 2

ROOT_DIR=$(pwd)
SKIP_BROWSER="0"
function local_read_args() {
  while (( "$#" )); do
  opt="$1"
  case $opt in
    -h|-\?|--\?--help)
      PRINT_USAGE=1
      QUICKSTART_ARGS="$SCRIPT $1"
      break
    ;;
    -b|--branch)
      BRANCH="$2"
      QUICKSTART_ARGS+=" $1 $2"
      shift
    ;;
    -o|--override)
      RECREATE_TAR="1"
      QUICKSTART_ARGS=" $SCRIPT"
    ;;
    --skip-setup)
      SKIP_SETUP=true
    ;;
    *)
      QUICKSTART_ARGS+=" $1"
      #echo $1
    ;;
  esac
  shift
  done

  if [[ -z $BRANCH ]]; then
    echo "Usage: $0 -b/--branch <branch> [--skip-setup]"
    exit 1
  fi
}

if [[ $(docker pull dtr.predix.io/predix-edge/predix-edge-mosquitto-amd64:latest) ]]; then
  echo "pull successfully"
else
  read -p "Enter your DTR user name> " DTR_USERNAME
  read -p "Enter your DTR password> " -s DTR_PASSWORD
  docker login dtr.predix.io -u $DTR_USERNAME -p $DTR_PASSWORD
  docker pull dtr.predix.io/predix-edge/predix-edge-mosquitto-amd64:latest
fi

docker pull dtr.predix.io/predix-edge/protocol-adapter-opcua-amd64:1.0.8
docker pull dtr.predix.io/predix-edge/cloud-gateway-timeseries-amd64:latest

#docker pull my-edge-app:1.0.0
PREDIX_SERVICES_APP="predix-services.tar.gz"
HELLO_WORLD_APP="edge-to-cloud.tar.gz"
pwd
cd services
if [[ "$RECREATE_TAR" == "1" || ! -e "predix-services.tar" ]]; then
  echo "Creating a predix-services.tar with required images"
  docker save -o predix-services.tar dtr.predix.io/predix-edge/protocol-adapter-opcua-amd64:latest dtr.predix.io/predix-edge/cloud-gateway-timeseries-amd64:latest
fi

if [[ "$RECREATE_TAR" == "1" || ! -e "$PREDIX_SERVICES_APP" ]]; then
  rm -rf $PREDIX_SERVICES_APP
  echo "Creating $PREDIX_SERVICES_APP with docker-compose.yml"
  tar -czvf $PREDIX_SERVICES_APP predix-services.tar docker-compose.yml
fi
cd ..
if [[ "$RECREATE_TAR" == "1" || ! -e "images.tar" ]]; then
  echo "Creating a images.tar with required images"
  docker save -o images.tar my-edge-app:1.0.0 dtr.predix.io/predix-edge/protocol-adapter-opcua-amd64:latest dtr.predix.io/predix-edge/cloud-gateway-timeseries-amd64:latest
fi

if [[ "$RECREATE_TAR" == "1" || ! -e "$HELLO_WORLD_APP" ]]; then
  rm -rf $HELLO_WORLD_APP
  echo "Creating $HELLO_WORLD_APP with docker-compose.yml"
  tar -czvf $HELLO_WORLD_APP images.tar docker-compose.yml
fi

HELLO_WORLD_CONFIG="predix-services-config.zip"
if [[ "$RECREATE_TAR" == "1" || ! -e "$HELLO_WORLD_CONFIG" ]]; then
  rm -rf $HELLO_WORLD_CONFIG
  echo "Compressing the configurations."
  cd config
  cat config-cloud-gateway.json
  zip -X -r ../$HELLO_WORLD_CONFIG *.json
  cd ../
fi

read -p "Enter the IP Address of Edge OS> " IP_ADDRESS
read -p "Enter the username for Edge OS> " LOGIN_USER
read -p "Enter your user password> " -s LOGIN_PASSWORD

pwd
expect -c "
  spawn scp -o \"StrictHostKeyChecking=no\" services/$PREDIX_SERVICES_APP $HELLO_WORLD_APP $HELLO_WORLD_CONFIG scripts/edge-to-cloud-run.sh data/access_token $LOGIN_USER@$IP_ADDRESS:/mnt/data/downloads
  set timeout 50
  expect {
    \"Are you sure you want to continue connecting\" {
      send \"yes\r\"
      expect \"assword:\"
      send "$LOGIN_PASSWORD\r"
    }
    \"assword:\" {
      send \"$LOGIN_PASSWORD\r\"
    }
  }
  expect \"*\# \"
  spawn ssh -o \"StrictHostKeyChecking=no\" root@$IP_ADDRESS
  set timeout 5
  expect {
    \"Are you sure you want to continue connecting\" {
      send \"yes\r\"
      expect \"assword:\"
      send \"$LOGIN_PASSWORD\r\"
    }
    "assword:" {
      send \"$LOGIN_PASSWORD\r\"
    }
  }
  expect \"*\# \"
  send \"su eauser /mnt/data/downloads/edge-to-cloud-run.sh\r\"
  set timeout 50
  expect \"*\#\"
  send \"rm -rf /mnt/data/downloads/*\r\"
  expect \"*\# \"
  send \"exit\r\"
"
