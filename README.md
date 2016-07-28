emqttd_plugin_kafka_bridge
===================

Emqttd kafka bridge Plugin, a bridge transfer messages from emqtt to kafka.

Build Plugin
------------

Add the plugin as submodule of emqttd project.

If the submodules exist:

```
git submodule update --remote plugins/emqttd_plugin_kafka_bridge
```

Orelse:

```
git submodule add https://github.com/vowstar/emqttd_plugin_kafka_bridge.git plugins/emqttd_plugin_kafka_bridge
```

And then build emqttd project.

Configure Plugin
----------------
TODO: Move broker list to here

File: etc/plugin.config

```erlang
[
  {emqttd_plugin_kafka_bridge, [
  	{kafka, [
      {bootstrap_broker, {"127.0.0.1", 9092} },
      {partition_strategy, strict_round_robin}
    ]}
  ]}
].

```

Broker URL and port setting:
-----------
``bootstrap_broker, {"127.0.0.1", 9092} ``

Partition strategy setting:
-----------
Round robin

``partition_strategy, strict_round_robin``

Random

``partition_strategy, random``


Load Plugin
-----------

```
./bin/emqttd_ctl plugins load emqttd_plugin_kafka_bridge
```

Kafka Topic and messages
-----------

### Topic

All message will be published on to kafka's ``broker_message`` Topic.

### Messages

In the following circumstances, you will receive kafka messages

- when a client connected broker

- when a client disconnected broker

- when a client subscribed a channel

- when a client unsubscribed a channel

- when a client published a message to a channel

- when a client delivered a message

- when a client acknowledged a messages 

All these message will published on to kafka.

#### Connected

```json
{
	"type":"connected",
	"client_id":"a client id",
	"cluster_node":"which emqtt node",
	"ts":1469690427
}
```
Note: key "ts" is unix timestamp.

#### Disconnected

```json
{
	"type":"disconnected",
	"client_id":"a client id",
	"reason":"reason why disconnected",
	"cluster_node":"which emqtt node",
	"ts":1469690427
}
```

#### Subscribed

```json
{
	"type":"subscribed",
	"client_id":"a client id",
	"topic":"which topic",
	"cluster_node":"which emqtt node",
	"ts":1469690427
}
```

#### Unsubscribed

```json
{
	"type":"unsubscribed",
	"client_id":"a client id",
	"topic":"which topic",
	"cluster_node":"which emqtt node",
	"ts":1469690427
}
```

#### Published

```json
{
	"type":"published",
	"client_id":"a client id",
	"topic":"which topic",
    "payload":"payload of message",
    "qos":1,
	"cluster_node":"which emqtt node",
	"ts":1469690427
}
```
Note: key "Qos" is QoS level of message.

#### Delivered

```json
{
	"type":"delivered",
	"client_id":"a client id",
	"form":"from client id",
	"topic":"which topic",
    "payload":"payload of message",
    "qos":1,
	"cluster_node":"which emqtt node",
	"ts":1469690427
}
```

#### Acknowledged

```json
{
	"type":"acked",
	"client_id":"a client id",
	"form":"from client id",
	"topic":"which topic",
    "payload":"payload of message",
    "qos":1,
	"cluster_node":"which emqtt node",
	"ts":1469690427
}
```

Author
------

Huang Rui <vowstar@gmail.com>

https://www.devicexx.com

Thanks
------
This project is based on the code of:

Erlang MQTT Broker [EMQTTD](https://github.com/emqtt/emqttd)

Helpshift Ekaf [ekaf](https://github.com/helpshift/ekaf)

And learn ideas form:

Gao dongchen's [emqttd_plugin_blackhole](https://github.com/gaodongchen/emqttd_plugin_blackhole)

Abhishek Chawla's [emqttd_publish_client_activity](https://github.com/abhidtu/emqttd_publish_client_activity)
