#!/bin/bash

docker save -o images.tar my-edge-app:1.0.0 protocol-adapter-opcua-amd64:latest predix-edge-mosquitto-amd64:latest cloud-gateway-amd64:latest

tar -czvf app.tar.gz images.tar docker-compose.yml

cd config
zip -X -r ../config.zip *.json
cd ../
