#!/bin/bash

docker service ls -f "name=predix-edge-broker_predix-edge-broker"

PREDIX_EDGE_BROKER_COUNT=$(docker service ls -f "name=predix-edge-broker_predix-edge-broker" -q | wc -l | awk '{print $1}')
echo "PREDIX_EDGE_BROKER_COUNT : $PREDIX_EDGE_BROKER_COUNT"
if [[ $PREDIX_EDGE_BROKER_COUNT -eq 0 ]]; then
  echo "Predix Edge Broker service not started"
  #docker stack deploy --compose-file docker/docker-compose-edge-broker.yml predix-edge-broker
  #echo "Predix Edge Broker service started"
else
  echo "Predix Edge Broker service already running"
fi
PREDIX_EDGE_SERVICES_OPCUA_COUNT=$(docker service ls -f "name=predix-edge-services_opcua" -q | wc -l | awk '{print $1}')
echo "PREDIX_EDGE_SERVICES_OPCUA_COUNT : $PREDIX_EDGE_SERVICES_OPCUA_COUNT"
if [[ $PREDIX_EDGE_SERVICES_OPCUA_COUNT -eq 0 ]]; then
  #docker stack deploy --compose-file docker/docker-compose-edge-opcua.yml predix-edge-services
  echo "Predix Edge OPCUA Adapter Service service started"
else
  echo "Predix Edge OPCUA Adapter Service service already running"
fi
PREDIX_EDGE_SERVICES_TIMESERIES_COUNT=$(docker service ls -f "name=predix-edge-services_cloud_gateway_timeseries" -q | wc -l | awk '{print $1}')
echo "PREDIX_EDGE_SERVICES_TIMESERIES_COUNT : $PREDIX_EDGE_SERVICES_TIMESERIES_COUNT"
if [[ $PREDIX_EDGE_SERVICES_TIMESERIES_COUNT -eq 0 ]]; then
  #docker stack deploy --compose-file docker/docker-compose-edge-opcua.yml predix-edge-services
  echo "Predix Edge Cloud Gateway Service service started"
else
  echo "Predix Edge Cloud Gateway Service service already running"
fi

sleep 10
docker service ls
