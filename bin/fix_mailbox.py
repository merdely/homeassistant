#!/usr/bin/env python3
import json
import os
import re
import sys
from time import sleep
import paho.mqtt.client as mqtt

mqtt_server = 'mqtt.erdely.in'
mqtt_port = 1883

secrets = os.path.dirname(os.path.dirname(os.path.realpath(sys.argv[0]))) + '/secrets.yaml'
with open(secrets, 'r') as file:
    for line in file.readlines():
        m = re.search(r"^fixmailbox_(username|password|topic): '?([^']+)'?$", line)
        if m and m.group(1) == 'username':
            mqtt_username = m.group(2)
        elif m and m.group(1) == 'password':
            mqtt_password = m.group(2)
        elif m and m.group(1) == 'topic':
            mqtt_topic = m.group(2)
file.close()

def on_connect(client, userdata, flags, rc):
    client.subscribe([(mqtt_topic, 0)])

def on_message(client, userdata, msg):
    if msg.topic == mqtt_topic:
        j = json.loads(msg.payload.decode('utf-8'))
        j['state']=0
        client.publish(mqtt_topic, payload=json.dumps(j), retain=True)


client = mqtt.Client()
client.on_connect = on_connect
client.on_message = on_message

client.username_pw_set(mqtt_username, mqtt_password)
client.connect(mqtt_server, mqtt_port, 60)

client.loop_start()
sleep(0.2)
client.loop_stop()

