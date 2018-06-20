#!/bin/bash
HOME_DIR=$(pwd)

#!/bin/bash
set -e

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

BRANCH="master"
PRINT_USAGE=0
SKIP_SETUP=false
#ASSET_MODEL="-amrmd predix-ui-seed/server/sample-data/predix-asset/asset-model-metadata.json predix-ui-seed/server/sample-data/predix-asset/asset-model.json"
SCRIPT="-script build-basic-app.sh -script-readargs build-basic-app-readargs.sh"
QUICKSTART_ARGS=" -uaa -ts -psts $SCRIPT"
VERSION_JSON="version.json"
PREDIX_SCRIPTS=predix-scripts
REPO_NAME=predix-edge-sample-scaler-nodejs
SCRIPT_NAME="edge-starter-sample-app.sh"
APP_DIR="edge-sample-nodejs"
APP_NAME="Predix Front End Basic App - Node.js Express with UAA, Asset, Time Series"
TOOLS="Cloud Foundry CLI, Git, Node.js, Maven, Predix CLI"
TOOLS_SWITCHES="--cf --git --nodejs --maven --predixcli"

local_read_args $@
IZON_SH="https://raw.githubusercontent.com/PredixDev/izon/$BRANCH/izon.sh"
VERSION_JSON_URL=https://raw.githubusercontent.com/PredixDev/$REPO_NAME/$BRANCH/version.json


function check_internet() {
  set +e
  echo ""
  echo "Checking internet connection..."
  curl "http://google.com" > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Unable to connect to internet, make sure you are connected to a network and check your proxy settings if behind a corporate proxy"
    echo "If you are behind a corporate proxy, set the 'http_proxy' and 'https_proxy' environment variables.   Please read this tutorial for detailed info about setting your proxy https://www.predix.io/resources/tutorials/tutorial-details.html?tutorial_id=1565"
    exit 1
  fi
  echo "OK"
  echo ""
  set -e
}

function init() {
  currentDir=$(pwd)
  if [[ $currentDir == *"scripts" ]]; then
    echo 'Please launch the script from the root dir of the project'
    exit 1
  fi
  if [[ ! $currentDir == *"$REPO_NAME" ]]; then
    mkdir -p $APP_DIR
    cd $APP_DIR
  fi

  check_internet


  #get the script that reads version.json
  eval "$(curl -s -L $IZON_SH)"

  getVersionFile
  getLocalSetupFuncs
}

if [[ $PRINT_USAGE == 1 ]]; then
  init
  __print_out_standard_usage
else
  if $SKIP_SETUP; then
    init
  else
    init
    __standard_mac_initialization
  fi
fi

getPredixScripts
#clone the repo itself if running from oneclick script
getCurrentRepo

echo "quickstart_args=$QUICKSTART_ARGS"
source $PREDIX_SCRIPTS/bash/quickstart.sh $QUICKSTART_ARGS


__append_new_line_log "Successfully completed $APP_NAME installation!" "$quickstartLogDir"
__append_new_line_log "" "$quickstartLogDir"

px set-env $INSTANCE_PREPENDER-predix-webapp-starter timeSeriesOnly true

px restage $INSTANCE_PREPENDER-predix-webapp-starter

pwd
cd $REPO_NAME

#echo "Cleaning (stop and rm) up Docker Containers"
#for container in $(docker ps -a | tail -n +2 | awk -F" " '{print $1}');
#do
#  echo "container : $container"
#  docker stop $container && docker rm $container
#done

#for image in $(docker images  -a | tail -n +2 | awk -F" " '{print $3}');
#do
#  echo "image $image"
#  docker rmi -f $image
#done

#for image in $(docker service ls | tail -n +2 | awk -F" " '{print $1}');
#do
#  echo "service $image"
#  docker service rm $image
#done

docker ps

docker images

docker service ls

docker login dtr.predix.io -u edge-user -p ",cwB^[/]2WQDXK&_"

docker pull dtr.predix.io/predix-edge/predix-edge-mosquitto-amd64:latest
docker pull dtr.predix.io/predix-edge/protocol-adapter-opcua-amd64:latest
docker pull dtr.predix.io/predix-edge/cloud-gateway-amd64:latest

docker tag dtr.predix.io/predix-edge/predix-edge-mosquitto-amd64:latest predix-edge-mosquitto-amd64:latest
docker tag dtr.predix.io/predix-edge/protocol-adapter-opcua-amd64:latest protocol-adapter-opcua-amd64:latest
docker tag dtr.predix.io/predix-edge/cloud-gateway-amd64:latest cloud-gateway-amd64:latest

pwd
ls

__find_and_replace ".*predix_zone_id\":.*" "          \"predix_zone_id\": \"$TIMESERIES_ZONE_ID\"," "config/config-cloud-gateway.json" "$quickstartLogDir"
__find_and_replace ".*proxy_url\":.*" "          \"proxy_url\": \"$http_proxy\"," "config/config-cloud-gateway.json" "$quickstartLogDir"
docker build -t my-edge-app:1.0.0 .
docker images

./get-access-token.sh $UAA_CLIENTID_GENERIC $UAA_CLIENTID_GENERIC_SECRET $TRUSTED_ISSUER_ID
cat data/access_token

docker stack deploy --compose-file docker-compose-dev.yml my-edge-app

#docker-compose -f docker-compose-dev.yml build
#docker-compose -f docker-compose-dev.yml up -d

#open https://svc-nodejs-starter.run.aws-usw02-pr.ice.predix.io