# /opt/mqtt-dashboard/app/dashboard.py
import os
from flask import Flask, render_template
from flask_socketio import SocketIO
from .mqtt_client import start_mqtt, set_socketio

def create_app():
    app = Flask(__name__, static_folder='static', template_folder='templates')
    app.config['SECRET_KEY'] = os.environ.get('MQTT_DASH_SECRET', 'cambiame_por_un_secreto_largo')
    socketio = SocketIO(app, async_mode='eventlet', cors_allowed_origins="*")
    # Inyectar socketio en mqtt client
    set_socketio(socketio)

    @app.route('/')
    def index():
        return render_template('dashboard.html')

    # Start MQTT client (daemon thread)
    # Ajusta rutas de certificados según tu instalación
    ca = os.environ.get('MQTT_CA', '/opt/mqtt-secure/certs/ca/ca.crt')
    cert = os.environ.get('MQTT_CLIENT_CERT', '/opt/mqtt-secure/certs/clients/garden_admin.crt')
    key = os.environ.get('MQTT_CLIENT_KEY', '/opt/mqtt-secure/certs/clients/garden_admin-key.pem')
    broker = os.environ.get('MQTT_BROKER_HOST', 'localhost')
    port = int(os.environ.get('MQTT_BROKER_PORT', 8883))
    user = os.environ.get('MQTT_CLIENT_USER', 'garden_admin')
    password = os.environ.get('MQTT_CLIENT_PASSWORD', 'AdminSecurePass456!')

    start_mqtt(broker_host=broker, broker_port=port, ca=ca, cert=cert, key=key, username=user, password=password)

    # Expose both app and socketio for the runner
    return app, socketio