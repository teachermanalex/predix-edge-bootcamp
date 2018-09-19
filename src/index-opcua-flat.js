// load the mqtt package so we can communicate with the app containers
var mqtt = require('mqtt')

// the opc-ua tag we will look for to scale
// *** EDIT THIS to put your tag name here. ***
var tagName = 'your-tag';

console.log("app starting");

//connect to the predix-edge-broker - use an environment variable if devloping locally
var predix_edge_broker = process.env.predix_edge_broker || 'predix-edge-broker';

console.log("mqtt connecting to " + predix_edge_broker);
var client  = mqtt.connect('mqtt://' + predix_edge_broker);

client.on('connect', function () {
  console.log("connected to "+ predix_edge_broker);
  //subscribe to the topic being published by the opc-ua container
  //*** EDIT THIS to the correct subscripe topic ***
  client.subscribe('subscribe-topic');
});

//handle each message as it is recieved
client.on('message', function (topic, message) {

  console.log("message recieved from " + predix_edge_broker+" : " + message.toString());

  //*** all app logic goes below here ***

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
  var value = item.data[tagName].val;

  //scale tagName's value * 100
  item.data[tagName].val = value * 100;

  //Stringify the object for publishing
  var scaled_item = JSON.stringify(item);

  //publish the OPCUA object back to the broker on the topic that
  //the cloud-gateway container is subscribing to
  //*** EDIT THIS to put the tag your timeseries is reading from here ***
  client.publish("timeseries_data", scaled_item);

  console.log("published scaled item to predix-edge-broker: " + scaled_item);
});
