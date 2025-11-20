# /opt/mqtt-dashboard/server.py
import eventlet
eventlet.monkey_patch()

from app.dashboard import create_app

app, socketio = create_app()

if __name__ == "__main__":
    # Ejecuta servidor en 0.0.0.0:5000
    socketio.run(app, host="0.0.0.0", port=5000)