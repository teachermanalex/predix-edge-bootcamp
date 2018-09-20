// load the mqtt package so we can communicate with the app containers
var mqtt = require('mqtt')
var fs = require('fs');
var config_file_name = '/config/config-my-opcua-app.json';

console.log("app starting");

// read config file
let configObj = JSON.parse(fs.readFileSync(config_file_name));

// Read the values for subSubject pubSubject and tagName from the config file
let subTopic = configObj.my_opcua_app.config.subTopic;
let pubTopic = configObj.my_opcua_app.config.pubTopic;
let tagName = configObj.my_opcua_app.config.tagName;

console.log("config file " + config_file_name + "read and parsed");
console.log("subTopic=" + subTopic + ", pubTopic=" + pubTopic + ", tagName=" + tagName);
//connect to the predix-edge-broker - use an environment variable if devloping locally
var predix_edge_broker = process.env.predix_edge_broker || 'predix-edge-broker';

console.log("mqtt connecting to " + predix_edge_broker);
var client  = mqtt.connect('mqtt://' + predix_edge_broker);

client.on('connect', function () {
  console.log("connected to "+ predix_edge_broker);
  //subscribe to the topic being published by the opc-ua container
  //*** EDIT THIS to the correct subscripe topic ***
  client.subscribe(subTopic);
});

//handle each message as it is recieved
client.on('message', function (topic, message) {

  console.log("message recieved from " + predix_edge_broker+" : " + message.toString());

  //read the message into a json object
  var item = JSON.parse(message);

  //extract the value from the OPCUA Flat data object
  //format is:
  //   { "data" : {
  //   		    "tagName1" : { "type" : "typestr", "val" : VALUE },
  //   		    "tagname2" : { "type" : "typestr", "val" : VALUE }
  //   		    ...
  //   		  }
  //   }
  try {
    var value = item.data[tagName].val;
  } catch (err) {
    console.log("Could not get data value from received item");
    console.log("looking for tagName=" + tagName + " failed. Returning.");
    return;
  }

  //scale tagName's value * 100
  item.data[tagName].val = value * 100;

  //Stringify the object for publishing
  var scaled_item = JSON.stringify(item);

  //publish the OPCUA object back to the broker on the topic that
  //the cloud-gateway container is subscribing to
  //*** EDIT THIS to put the tag your timeseries is reading from here ***
  client.publish("pub_topic", scaled_item);

  console.log("published scaled item to predix-edge-broker: " + scaled_item);
});
