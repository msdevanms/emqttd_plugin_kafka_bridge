emqttd_plugin_kafka_bridge
===================

emqttd kafka bridge Plugin

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

  ]}
].

```


Load Plugin
-----------

```
./bin/emqttd_ctl plugins load emqttd_plugin_kafka_bridge
```

Author
------

Huang Rui <vowstar@gmail.com>

https://www.devicexx.com
