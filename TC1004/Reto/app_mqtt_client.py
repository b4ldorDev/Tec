# /opt/mqtt-dashboard/app/mqtt_client.py
import threading
import json
import ssl
import paho.mqtt.client as mqtt

# socketio será inyectado desde create_app en dashboard.py
socketio = None

def set_socketio(s):
    global socketio
    socketio = s

def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("MQTT connected, subscribing to garden/#")
        client.subscribe("garden/#")
    else:
        print("MQTT connection failed with rc=", rc)

def on_message(client, userdata, msg):
    payload = msg.payload.decode(errors='ignore')
    try:
        data = json.loads(payload)
    except Exception:
        data = {'raw': payload}
    record = {'topic': msg.topic, 'payload': data}
    print("MQTT ->", record['topic'])
    if socketio:
        socketio.emit('mqtt_message', record)

def start_mqtt(broker_host='localhost', broker_port=8883,
               ca=None, cert=None, key=None, username=None, password=None):
    client = mqtt.Client()
    if ca:
        try:
            client.tls_set(ca_certs=ca, certfile=cert, keyfile=key, cert_reqs=ssl.CERT_REQUIRED)
        except Exception as e:
            print("Warning: tls_set error:", e)
    if username:
        client.username_pw_set(username, password)
    client.on_connect = on_connect
    client.on_message = on_message
    def _run():
        try:
            client.connect(broker_host, broker_port, 60)
            client.loop_forever()
        except Exception as e:
            print("MQTT client error:", e)
    thread = threading.Thread(target=_run, daemon=True)
    thread.start()
    return client