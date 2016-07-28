%%%-----------------------------------------------------------------------------
%%% Copyright (c) 2016 Huang Rui<vowstar@gmail.com>, All Rights Reserved.
%%%
%%% Permission is hereby granted, free of charge, to any person obtaining a copy
%%% of this software and associated documentation files (the "Software"), to deal
%%% in the Software without restriction, including without limitation the rights
%%% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
%%% copies of the Software, and to permit persons to whom the Software is
%%% furnished to do so, subject to the following conditions:
%%%
%%% The above copyright notice and this permission notice shall be included in all
%%% copies or substantial portions of the Software.
%%%
%%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
%%% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
%%% SOFTWARE.
%%%-----------------------------------------------------------------------------
%%% @doc
%%% emqttd_plugin_kafka_bridge.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(emqttd_plugin_kafka_bridge).

-include("../../../include/emqttd.hrl").

-include("../../../include/emqttd_protocol.hrl").

-include("../../../include/emqttd_internal.hrl").

-export([load/1, unload/0]).

%% Hooks functions
-export([on_client_connected/3, on_client_disconnected/3]).

-export([on_client_subscribe/3, on_client_subscribe_after/3, on_client_unsubscribe/3]).

-export([on_message_publish/2, on_message_delivered/3, on_message_acked/3]).

-record(struct, {lst=[]}).

%% Called when the plugin application start
load(Env) ->
    ekaf_init([Env]),
    emqttd:hook('client.connected', fun ?MODULE:on_client_connected/3, [Env]),
    emqttd:hook('client.disconnected', fun ?MODULE:on_client_disconnected/3, [Env]),
    emqttd:hook('client.subscribe', fun ?MODULE:on_client_subscribe/3, [Env]),
    emqttd:hook('client.subscribe.after', fun ?MODULE:on_client_subscribe_after/3, [Env]),
    emqttd:hook('client.unsubscribe', fun ?MODULE:on_client_unsubscribe/3, [Env]),
    emqttd:hook('message.publish', fun ?MODULE:on_message_publish/2, [Env]),
    emqttd:hook('message.delivered', fun ?MODULE:on_message_delivered/3, [Env]),
    emqttd:hook('message.acked', fun ?MODULE:on_message_acked/3, [Env]).

%%-----------client connect start-----------------------------------%%

on_client_connected(ConnAck, Client = #mqtt_client{client_id  = ClientId}, _Env) ->
    io:format("client ~s connected, connack: ~w~n", [ClientId, ConnAck]),

    Json = mochijson2:encode([
        {type, <<"connected">>},
        {clientid, ClientId},
        {cluster_node, node()},
        {ts, emqttd_time:now_to_secs()}
    ]),
    
    ekaf:produce_async_batched(<<"broker_message">>, list_to_binary(Json)),

    {ok, Client}.

%%-----------client connect end-------------------------------------%%



%%-----------client disconnect start---------------------------------%%

on_client_disconnected(Reason, ClientId, _Env) ->
    io:format("client ~s disconnected, reason: ~w~n", [ClientId, Reason]),

    Json = mochijson2:encode([
        {type, <<"disconnected">>},
        {clientid, ClientId},
        {reason, Reason},
        {cluster_node, node()},
        {ts, emqttd_time:now_to_secs()}
    ]),

    ekaf:produce_async_batched(<<"broker_message">>, list_to_binary(Json)),

    ok.

%%-----------client disconnect end-----------------------------------%%



%%-----------client subscribed start---------------------------------------%%

%% should retain TopicTable
on_client_subscribe(ClientId, TopicTable, _Env) ->
    io:format("client ~s will subscribe ~p~n", [ClientId, TopicTable]),
    {ok, TopicTable}.
   
on_client_subscribe_after(ClientId, TopicTable, _Env) ->
    io:format("client ~s subscribed ~p~n", [ClientId, TopicTable]),
    
    case TopicTable of
        [_|_] -> 
            %% If TopicTable list is not empty
            Key = proplists:get_keys(TopicTable),
            %% build json to send using ClientId
            Json = mochijson2:encode([
                {type, <<"subscribed">>},
                {client_id, ClientId},
                {topic, lists:last(Key)},
                {cluster_node, node()},
                {ts, emqttd_time:now_to_secs()}
            ]),
            ekaf:produce_async_batched(<<"broker_message">>, list_to_binary(Json));
        _ -> 
            %% If TopicTable is empty
            io:format("empty topic ~n")
    end,

    {ok, TopicTable}.

%%-----------client subscribed end----------------------------------------%%



%%-----------client unsubscribed start----------------------------------------%%

on_client_unsubscribe(ClientId, Topics, _Env) ->
    io:format("client ~s unsubscribe ~p~n", [ClientId, Topics]),

    % build json to send using ClientId
    Json = mochijson2:encode([
        {type, <<"unsubscribed">>},
        {client_id, ClientId},
        {topic, lists:last(Topics)},
        {cluster_node, node()},
        {ts, emqttd_time:now_to_secs()}
    ]),
    
    ekaf:produce_async_batched(<<"broker_message">>, list_to_binary(Json)),
    
    {ok, Topics}.

%%-----------client unsubscribed end----------------------------------------%%



%%-----------message publish start--------------------------------------%%

%% transform message and return
on_message_publish(Message = #mqtt_message{topic = <<"$SYS/", _/binary>>}, _Env) ->
    {ok, Message};

on_message_publish(Message, _Env) ->
    io:format("publish ~s~n", [emqttd_message:format(Message)]),   

    From = Message#mqtt_message.from,
    Sender =  Message#mqtt_message.sender,
    Topic = Message#mqtt_message.topic,
    Payload = Message#mqtt_message.payload, 
    QoS = Message#mqtt_message.qos,
    Timestamp = Message#mqtt_message.timestamp,

    Json = mochijson2:encode([
        {type, <<"published">>},
        {client_id, From},
        {topic, Topic},
        {payload, Payload},
        {qos, QoS},
        {cluster_node, node()},
        {ts, emqttd_time:now_to_secs(Timestamp)}
    ]),

    ekaf:produce_async_batched(<<"broker_message">>, list_to_binary(Json)),

    {ok, Message}.

%%-----------message delivered start--------------------------------------%%
on_message_delivered(ClientId, Message, _Env) ->
    io:format("delivered to client ~s: ~s~n", [ClientId, emqttd_message:format(Message)]),

    From = Message#mqtt_message.from,
    Sender =  Message#mqtt_message.sender,
    Topic = Message#mqtt_message.topic,
    Payload = Message#mqtt_message.payload, 
    QoS = Message#mqtt_message.qos,
    Timestamp = Message#mqtt_message.timestamp,

    Json = mochijson2:encode([
        {type, <<"delivered">>},
        {client_id, ClientId},
        {from, From},
        {topic, Topic},
        {payload, Payload},
        {qos, QoS},
        {cluster_node, node()},
        {ts, emqttd_time:now_to_secs(Timestamp)}
    ]),

    ekaf:produce_async_batched(<<"broker_message">>, list_to_binary(Json)),

    {ok, Message}.
%%-----------message delivered end----------------------------------------%%

%%-----------acknowledgement publish start----------------------------%%
on_message_acked(ClientId, Message, _Env) ->
    io:format("client ~s acked: ~s~n", [ClientId, emqttd_message:format(Message)]),   

    From = Message#mqtt_message.from,
    Sender =  Message#mqtt_message.sender,
    Topic = Message#mqtt_message.topic,
    Payload = Message#mqtt_message.payload, 
    QoS = Message#mqtt_message.qos,
    Timestamp = Message#mqtt_message.timestamp,

    Json = mochijson2:encode([
        {type, <<"acked">>},
        {client_id, ClientId},
        {from, From},
        {topic, Topic},
        {payload, Payload},
        {qos, QoS},
        {cluster_node, node()},
        {ts, emqttd_time:now_to_secs(Timestamp)}
    ]),

    ekaf:produce_async_batched(<<"broker_message">>, list_to_binary(Json)),
    {ok, Message}.

%% ===================================================================
%% Test
%% ===================================================================

ekaf_init(_Env) ->
    %% Get parameters
    {ok, Kafka} = application:get_env(emqttd_plugin_kafka_bridge, kafka),
    BootstrapBroker = proplists:get_value(bootstrap_broker, Kafka),
    PartitionStrategy= proplists:get_value(partition_strategy, Kafka),
    %% Set partition strategy, like application:set_env(ekaf, ekaf_partition_strategy, strict_round_robin),
    application:set_env(ekaf, ekaf_partition_strategy, PartitionStrategy),
    %% Set broker url and port, like application:set_env(ekaf, ekaf_bootstrap_broker, {"127.0.0.1", 9092}),
    application:set_env(ekaf, ekaf_bootstrap_broker, BootstrapBroker),
    %% Set topic
    application:set_env(ekaf, ekaf_bootstrap_topics, <<"broker_message">>),

    {ok, _} = application:ensure_all_started(kafkamocker),
    {ok, _} = application:ensure_all_started(gproc),
    {ok, _} = application:ensure_all_started(ranch),
    {ok, _} = application:ensure_all_started(ekaf),

    io:format("Init ekaf with ~p~n", [BootstrapBroker]).


%% Called when the plugin application stop
unload() ->
    emqttd:unhook('client.connected', fun ?MODULE:on_client_connected/3),
    emqttd:unhook('client.disconnected', fun ?MODULE:on_client_disconnected/3),
    emqttd:unhook('client.subscribe', fun ?MODULE:on_client_subscribe/3),
    emqttd:unhook('client.subscribe.after', fun ?MODULE:on_client_subscribe_after/3),
    emqttd:unhook('client.unsubscribe', fun ?MODULE:on_client_unsubscribe/3),
    emqttd:unhook('message.publish', fun ?MODULE:on_message_publish/2),
    emqttd:unhook('message.acked', fun ?MODULE:on_message_acked/3),
    emqttd:unhook('message.delivered', fun ?MODULE:on_message_delivered/3).

