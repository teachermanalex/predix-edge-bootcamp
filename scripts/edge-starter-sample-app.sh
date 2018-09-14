#!/bin/bash
HOME_DIR=$(pwd)

#!/bin/bash
set -e

RUN_QUICKSTART=1
SKIP_PREDIX_SERVICES="false"
function local_read_args() {
  while (( "$#" )); do
  opt="$1"
  case $opt in
    -h|-\?|--\?--help)
      PRINT_USAGE=1
      QUICKSTART_ARGS="$SCRIPT $1"
      break
    ;;
    --no-quickstart)
      RUN_QUICKSTART=0
    ;;
    -i)
      INSTANCE_PREPENDER="$2"
    ;;
    -b|--branch)
      BRANCH="$2"
      QUICKSTART_ARGS+=" $1 $2"
      shift
    ;;
    -o|--override)
      QUICKSTART_ARGS=" $SCRIPT"
    ;;
    --skip-predix-services)
      SKIP_PREDIX_SERVICES="true"
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

# default settings
BRANCH="master"
PRINT_USAGE=0
SKIP_SETUP=false

IZON_SH="https://raw.githubusercontent.com/PredixDev/izon/1.1.0/izon2.sh"
#ASSET_MODEL="-amrmd predix-ui-seed/server/sample-data/predix-asset/asset-model-metadata.json predix-ui-seed/server/sample-data/predix-asset/asset-model.json"
SCRIPT="-script build-basic-app.sh -script-readargs build-basic-app-readargs.sh"
VERSION_JSON="version.json"
PREDIX_SCRIPTS=predix-scripts
REPO_NAME=predix-edge-sample-scaler-nodejs
SCRIPT_NAME="edge-starter-sample-app.sh"
APP_DIR="edge-sample-nodejs"
APP_NAME="Predix Front End Basic App - Node.js Express with UAA, Asset, Time Series"
GITHUB_RAW="https://raw.githubusercontent.com/PredixDev"
TOOLS="Cloud Foundry CLI, Git, Node.js, Predix CLI"
TOOLS_SWITCHES="--cf --git --nodejs --predixcli"

# Process switches
local_read_args $@

#variables after processing switches
SCRIPT_LOC="$GITHUB_RAW/$REPO_NAME/$BRANCH/scripts/$SCRIPT_NAME"
VERSION_JSON_URL=$GITHUB_RAW/$REPO_NAME/$BRANCH/version.json

if [[ "$SKIP_PREDIX_SERVICES" == "true" ]]; then
  QUICKSTART_ARGS="$QUICKSTART_ARGS -p $SCRIPT"
else
  QUICKSTART_ARGS="$QUICKSTART_ARGS -uaa -ts -psts $SCRIPT"
fi

function check_internet() {
  set +e
  echo ""
  echo "Checking internet connection..."
  curl "http://github.com" > /dev/null 2>&1
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
  getUsingCurl $SCRIPT_LOC
  chmod 755 $SCRIPT_NAME;
  getVersionFile
  getLocalSetupFuncs $GITHUB_RAW
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
export TIMESERIES_CHART_ONLY="true"
source $PREDIX_SCRIPTS/bash/quickstart.sh $QUICKSTART_ARGS

if [[ "$RUN_QUICKSTART" == "1" ]]; then
  pwd
  cd $REPO_NAME

  set -e
  docker pull dtr.predix.io/predix-edge/predix-edge-mosquitto-amd64:latest
  docker pull dtr.predix.io/predix-edge/protocol-adapter-opcua-amd64:latest
  docker pull dtr.predix.io/predix-edge/cloud-gateway-timeseries-amd64:latest

  docker ps

  docker images

  pwd
  ls
  if [[ "$TIMESERIES_INGEST_URI" == "" ]]; then
    getTimeseriesIngestUriFromInstance $TIMESERIES_INSTANCE_NAME
  fi
  if [[ "$TIMESERIES_QUERY_URI" == "" ]]; then
    getTimeseriesQueryUriFromInstance $TIMESERIES_INSTANCE_NAME
  fi
  if [[ "$TIMESERIES_ZONE_ID" == "" ]]; then
    getTimeseriesZoneIdFromInstance $TIMESERIES_INSTANCE_NAME
  fi
  if [[ "$UAA_URL" == "" ]]; then
    getTrustedIssuerIdFromInstance $UAA_INSTANCE_NAME
  fi
  echo "TIMESERIES_ZONE_ID : $TIMESERIES_ZONE_ID"
  __find_and_replace ".*predix_zone_id\":.*" "          \"predix_zone_id\": \"$TIMESERIES_ZONE_ID\"," "config/config-cloud-gateway.json" "$quickstartLogDir"
  echo "proxy_url : $http_proxy"
  __find_and_replace ".*proxy_url\":.*" "          \"proxy_url\": \"$http_proxy\"" "config/config-cloud-gateway.json" "$quickstartLogDir"

  ./scripts/get-access-token.sh $UAA_CLIENTID_GENERIC $UAA_CLIENTID_GENERIC_SECRET $TRUSTED_ISSUER_ID
  pwd
  cat data/access_token

  mkdir data/store_forward_queue
  chmod 777 data/store_forward_queue
  
  pwd
  ls
  docker service ls -f "name=predix-edge-broker_predix-edge-broker"

  docker stack deploy --with-registry-auth --compose-file docker-compose-edge-broker.yml predix-edge-broker
  sleep 10
  if [[  $(docker service ls -f "name=predix-edge-broker" | grep 0/1 | wc -l) == "1" ]]; then
    docker service ls
    echo 'Error: One of the predix-edge-broker services did not launch'
    exit 1
  fi

  docker stack deploy --with-registry-auth --compose-file docker-compose-services-local.yml predix-edge-services
  sleep 10
  if [[  $(docker service ls -f "name=predix-edge-services" | grep 0/1 | wc -l) == "1" ]]; then
    docker service ls
    echo 'Error: One of the predix-edge-services did not launch'
    exit 1
  fi

  docker build -t edge-to-cloud-filter:1.0.0 . --build-arg http_proxy --build-arg https_proxy
  docker stack deploy --compose-file docker-compose.yml edge-to-cloud
  sleep 10
  if [[  $(docker service ls -f "name=edge-to-cloud" | grep 0/1 | wc -l) == "1" ]]; then
    docker service ls
    echo 'Error: One of the edge-to-cloud services did not launch'
    exit 1
  fi

  docker stack ls
  docker stack services predix-edge-broker
  docker stack services predix-edge-services
  docker stack services edge-to-cloud
  docker ps
fi

cat $SUMMARY_TEXTFILE
__append_new_line_log "" "$logDir"
__append_new_line_log "Successfully completed Edge to Cloud App installation!" "$quickstartLogDir"
__append_new_line_log "" "$logDir"
