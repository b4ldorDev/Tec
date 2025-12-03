contents:
import paho.mqtt.client as mqtt
from sqlalchemy.orm import Session
from database import SessionLocal
import models
import logging
from datetime import datetime

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

# CONFIGURACIÓN MQTT
BROKER = "192.168.0.71"
PORT = 1883
TOPIC = "garden/sensors/data"

def validar_datos(temp: float, hum: float) -> bool:
    """Valida que los datos estén en rangos razonables"""
    if not (-50 <= temp <= 100):
        logger.error("dato inesperado")
        return False

    if not (0 <= hum <= 100):
        logger.error("dato inesperado")
        return False

    return True

def get_or_create_sensor(db: Session, nombre: str):
    """Busca un sensor por nombre; si no existe lo crea y devuelve la instancia"""
    sensor = db.query(models.Sensor).filter(models.Sensor.nombre == nombre).first()
    if sensor:
        return sensor

    try:
        sensor = models.Sensor(nombre=nombre)
        db.add(sensor)
        db.commit()
        db.refresh(sensor)
        return sensor
    except Exception:
        db.rollback()
        return None

def guardar_medicion(id_sensor: int, temp: float, hum: float):
    """Guarda una medición en PostgreSQL"""
    db = SessionLocal()
    try:
        medicion = models.Medicion(
            id_sensor=id_sensor,
            temperatura=temp,
            humedad=hum,
            hora=datetime.now()
        )
        db.add(medicion)
        db.commit()

        sensor = db.query(models.Sensor).filter(models.Sensor.id_sensor == id_sensor).first()
        planta = db.query(models.Planta).filter(models.Planta.id_sensor == id_sensor).first()

        sensor_nombre = sensor.nombre if sensor else f"sensor_{id_sensor}"
        planta_nombre = planta.nombre if planta else None

        logger.info(f"medicion guardada: {sensor_nombre} {temp}C {hum}%")

        # Verificar alertas de planta 
        if planta:
            try:
                if temp < float(planta.temp_min) or temp > float(planta.temp_max):
                    logger.warning(f"Temperatura fuera de rango para {planta.nombre}")
                if hum < float(planta.humedad_min) or hum > float(planta.humedad_max):
                    logger.warning(f"Humedad fuera de rango para {planta.nombre}")
            except Exception:
                # Si los límites en la DB no son válidos, marcar como dato inesperado
                logger.error("dato inesperado")

    except Exception:
        db.rollback()
        logger.error("dato inesperado")
    finally:
        db.close()

def on_connect(client, userdata, flags, rc):
    """Callback cuando se conecta al broker MQTT"""
    if rc == 0:
        client.subscribe(TOPIC)
    else:
        logger.error("dato inesperado")

def on_message(client, userdata, msg):
    """Callback cuando llega un mensaje MQTT"""
    try:
        mensaje = msg.payload.decode('utf-8').strip()

        # Formato esperado: Nombre-Matricula-Temperatura-Humedad
        datos = mensaje.split('-')
        if len(datos) != 4:
            logger.error("dato inesperado")
            return

        nombre = datos[0].strip()
        # matricula no se usa para el procesamiento, pero debe existir
        matricula = datos[1].strip()
        if matricula == "":
            logger.error("dato inesperado")
            return

        try:
            temperatura = float(datos[2].strip())
            humedad = float(datos[3].strip())
        except ValueError:
            logger.error("dato inesperado")
            return

        if not validar_datos(temperatura, humedad):
            return

        db = SessionLocal()
        try:
            sensor = get_or_create_sensor(db, nombre)
            if not sensor:
                logger.error("dato inesperado")
                return

            # Intentar obtener id del sensor por los nombres comunes de campo
            id_sensor = getattr(sensor, "id_sensor", None) or getattr(sensor, "id", None)
            if not id_sensor:
                logger.error("dato inesperado")
                return

            guardar_medicion(id_sensor, temperatura, humedad)
        finally:
            db.close()

    except Exception:
        logger.error("dato inesperado")

def main():
    client = mqtt.Client()
    client.on_connect = on_connect
    client.on_message = on_message

    try:
        client.connect(BROKER, PORT, 60)
        client.loop_forever()
    except KeyboardInterrupt:
        client.disconnect()
    except Exception:
        logger.error("dato inesperado")

if __name__ == "__main__":
    main()
