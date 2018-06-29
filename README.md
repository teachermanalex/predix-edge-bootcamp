## Predix Edge Sample Scaling App in NodeJS

The intent of this app is to illustrate building and deploying a basic Predix Edge app that communicates with other common Predix Edge comtainer services.  The functionality is intended to be extremely simple with the focus being on the fundamentals of constructing the app.

The functionality of app is to subscribe to tag values that are being published to the data broker by a the OPC-UA protocol adapater.  The app then identifies a specific tag, scales the value by a factor of 1000, and puts the resulting tag value back on the data broker.  The Cloud Gateway service then picks of the scaled tag and publishes it to the Predix Cloud Timeseries service.

#### Software You will Need

In order to devlop and run this sample locally you will need **NodeJS** and **Docker** on your devlopment PC.

You will also need the *UAA URL*, *ClientID* and *Secret* for the Predix Cloud Timeseries service to which you wish to ingest the app's output.

#### Step 1: Install the core Predix Edge components

To get started devloping locally you will need to pull the core Predix Edge Docker images onto your local machine.  

This will first require you to logon to the Predix Docker Trusted Registry (DTR).  We are supplying all devlopers with the temporary credentials listed below. Please connect with Predix DTR team to get the credentials

```bash
$ docker login dtr.predix.io
$ Username: <dtr user name>
$ Password: <dtr user password>
```

Now pull in the images our app will use.

```bash
$ docker pull dtr.predix.io/predix-edge/predix-edge-mosquitto-amd64:latest

$ docker pull dtr.predix.io/predix-edge/protocol-adapter-opcua-amd64:latest

$ docker pull dtr.predix.io/predix-edge/cloud-gateway-amd64:latest
```
We must now rename the images locally so they can be deployed to an Edge device by removing the reference to the dtr url.

*This step will no longer be neccesary after integration between Predix Edge and the Predix DTR has been completed*.

```bash
$ docker tag dtr.predix.io/predix-edge/predix-edge-mosquitto-amd64:latest predix-edge-mosquitto-amd64:latest

$ docker tag dtr.predix.io/predix-edge/protocol-adapter-opcua-amd64:latest protocol-adapter-opcua-amd64:latest

$ docker tag dtr.predix.io/predix-edge/cloud-gateway-amd64:latest cloud-gateway-amd64:latest
```
Finally, create a Docker Swarm on your machine.  You only need to do this once on your machine.  If you have done so in the past you can disregard this step.

```bash
$ docker swarm init
```

#### Step 2: Clone this Repository

Clone this repository to download all of the source code.
```bash
$ git clone https://github.com/PredixDev/predix-edge-sample-scaler-nodejs.git
```

#### Step 3: Review the App Functionality
The functionality of this NodeJS app is located in the **src** folder in a file named **index.js**.  Please review the file and the comments around each like to understand how it works.

#### Step 4: Create a Docker image of the App

The **Dockerfile** is used to compile your app into a Docker image that can be run in Predix Edge .  Please review the file and the comments around each like to understand how it works.

The only modification you may have to make are the two proxy environment variables:

```bash
ENV http_proxy=http://proxy-src.research.ge.com:8080
ENV https_proxy=http://proxy-src.research.ge.com:8080
```
Update the values to to reflect the proxies you use on your machine to reach the Internet.  If you are not behind a proxy, you can remove these two lines.

The *docker build* command is used to generate the docker image from the source code of your app.  Executing this command from the commandline will create a Docker image named **my-edge-app** with a version of **1.0.0**.

```bash
$ docker build -t my-edge-app:1.0.0 .
```

After the build completes you can see your imaage, as well as the core Predix Edge images we pulled onto your machine with the *docker images* command.

```bash
$ docker images
```
#### Step 5: Configure the App
Predix Edge apps contain a series of configration files to define parameters for the app's deployment and execution.  Our app contains the following configuration files.

#### docker-compose.yml
App deployment parameters are defined in the **docker-compse.yml** file.  This file defines the Docker images used to construt the application.  It also contains parameters for configuring the image, such as any  specific configuration files required by each image.

Our project includes a *docker-compose.yml* file and a *docker-compose-dev.yml* file.  The "-dev" version is configured to run the app locally on your machine.  The "non-dev" version is used to deploy the app to an actual Predix Edge device or VM.

The primary differences in the "non-dev" include:

- Removal of all volume mounts.  Predix Edge will automatically inject a **/config** and **/data** volume into your app at runtime.
- Removal of Proxy and DNS settings.  Apps running on a Predix Edge device will utilize these values configured on the device.

The only change you may have ot make in the "-dev" version of this file is the proxy settings for the Cloud Gateway service.  Change the **https_proxy** value if your machine is behind a different proxy.

```yaml
  cloud_gateway:
    image: "cloud-gateway-amd64:latest"
    environment:
      config: "/config/config-cloud-gateway.json"
      https_proxy: "http://proxy-src.research.ge.com:8080"
    dns:
      - "10.220.220.220"
    volumes:
      - ./config:/config
      - ./data:/data
      - ./data:/edge-agent
```

#### config/config-opcua.json
This configuration file is utilized by the OPC-UA Protocol Adapter image to connect to an OPC-UA server, subscribe to a series of 3 tags and publish the results on the data broker in a timersies format.  It is configured to use an OPC-UA simulator running on the GE network.  Unless you would like to connect to a different server or simulator, you should not have to change this file.

Below is a subset of the config file highlighting key properties you would change if obtaining data form a different OPC-UA server:

- **transport_addr** - the IP address or URL to the OPC-UA server
- **data_map** - the array of tags the app is subscribing to
- **node_ref** - in the mqtt section is the topic on which the OPC-UA data will be published to the data broker for consumption by the other containers in the app

```yaml
    "opcua": {
      "type": "opcuasubflat",
      "config": {
          "transport_addr": "opc-tcp://3.39.89.86:49310",
          "log_level": "debug",
          "data_map": [
            {
              "alias": "Integration.App.Device1.FLOAT1",
              "id": "ns=2;s=Simulator.Device1.FLOAT1"
            },
            {
              "alias": "Integration.App.Device1.FLOAT2",
              "id": "ns=2;s=Simulator.Device1.FLOAT2"
            },
            {
              "alias": "Integration.App.Device1.FLOAT3",
              "id": "ns=2;s=Simulator.Device1.FLOAT3"
            }
          ]
      }

    "mqtt": {
        "type": "cdpoutqueue",
        "config": {
            "transport_addr": "mqtt-tcp://mosquitto",
            "node_ref": "opcua_data",
            "method": "pub",
            "log_level": "debug",
            "log_name": "opcua_mqtt",
            "directory": "/data/mqtt_queue",
            "max_cache_size_units": "%",
            "max_cache_size": 90
        }
```
#### config/config-cloud-gateway.json
This file is used by the Cloud Gateway service and contains properties indicating which Predix Cloud Timeseries service to inject the data.

- **transport_addr** - (in the timeseries section) is the websockets URL for your Predix Cloud Timeseries service.  Note, the Cloud Gateway container uses its own protocol prefixes for sending data to different destinations.  You are likely used to seeing this as wss://.  For this component, pstss:// should be the protocol prefix of the URL.  Everything else is exavlty as defined by your Predix Cloud timeseries service.
- **predix_zone_id** - (in the timeseries section) is the zone ID of the timeseries service you with to transmit the data to
- **node_ref** - (in the mqtt section) is the topic on which the Cloud Gateway service will subscribe to data published by the app to be injected into the timeseries database.  If you recall the sample app source code, **timeseries_data** is the topic to which the scaled values are put back on the broker.

**Action**: *You should change the value of **predix_zone_id** and ingestion URL to match the timeseries service to which you intend to publish data when running this sample.*

```yaml
    "mqtt": {
      "type": "cdpin",
      "config": {
        "transport_addr": "mqtt-tcp://predix-edge-broker",
        "node_ref": "timeseries_data",
        "method": "sub",
        "log_name":"gateway_mqtt_source",
        "log_level": "debug"
      }
    }

    "timeseries": {
      "type": "cdpoutqueue",
      "config": {
        "transport_addr": "pxtss://gateway-predix-data-services.run.aws-usw02-pr.ice.predix.io/v1/stream/messages",
        "node_ref": "timeseries",
        "method": "set",
        "log_name":"gateway_predix_sink",
        "log_level": "debug",
        "directory": "/data/store_forward_queue",
        "max_cache_size_units": "%",
        "max_cache_size": 90,
        "options": {
          "predix_zone_id": "54d53783-f868-4a3a-9a8e-a0d9a5d57299",
          "token_file": "/edge-agent/access_token",
          "proxy_url": "$https_proxy"
        }
      }
    }
```
#### Step 6: Run the App Locally
The result of this app is to publish a scaled value to Predix Cloud Timeseries.  In order to do so, they app requires a UAA token with permissions to ingest data.  On a Predix Edge device, apps obtain this token from the device once it is enrolled to Edge Manager.

During devlopment, though, you must generate a token to be used by the app.  To do so, we have included a **get-access-token.sh** script that will obtain a UAA token and put it in a location that is accessable by the app.

The script takes three input parameters:
- Client ID - must have permissions to ingest data into your timeseries instance
- Secret
- UAA URL - must be the full URL including the /oauth/token ending

```bash
$ ./get-access-token.sh my-client-id my-secret -my-uaa-url
```
After you run the script, a file names *access_token* will be created in the data folder of the app.  The app is configured to use this file to obatin the token for ytransmitting data to the cloud.

To run the app, execute the following command from the commandline.  This will run the app with the "-dev" version of the docker-compose file.

```bash
$ docker stack deploy --compose-file docker-compose-dev.yml my-edge-app
```
You will see a series of messages indicating the services of your app are being created.  When that command completes, use the *docker ps* command to view the state of your apps containers.

```bash
$ docker ps
```

You van view the logs generated by each container in the app by executing the docker logs command and passing in the CONTAINER ID for any of the running containers.

For example (where 0000000000 is one of the container ids displayed from your docker ps output):

```bash
$ docker logs 0000000000
```

#### Step 7: Verify the App is Working
If the app is working, you should see a tag named **My.App.DOUBLE1.scaled_x_1000** in your Predix Cloud Timeseries service.  Use a tool such as Postman or the Predix Tool Kit API Explorere to query timeseries and view your data.

#### Step 8: Package and Deploy the App to a Predix Edge VM
Packaging the app involves creating a tar.gz file with your app's Docker images and docker-compose.yml file.  You then create a zip file containing your app's configuration files.

Create the **app.tar.gz** file:
```bash
$ docker save -o images.tar my-edge-app:1.0.0 protocol-adapter-opcua-amd64:latest predix-edge-mosquitto-amd64:latest cloud-gateway-amd64:latest

$ tar -czvf app.tar.gz images.tar docker-compose.yml
```

Create the **config.zip** file.  

*Note, you only want to zip up the actual files, not the config folder that contains the files*.

```bash
$ cd config
$ zip -X -r ../config.zip *.json
$ cd ../
```

Once you have created these two files, you can upload them to your Edge Manager's repository and deploy them to your enrolled Predix Edge VM.

[![Analytics](https://ga-beacon.appspot.com/UA-82773213-1/wind-workbench/readme?pixel)](https://github.com/PredixDev)
