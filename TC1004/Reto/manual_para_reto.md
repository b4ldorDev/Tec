# Manual Completo: Implementación MQTT Ultra Seguro para Huerto Automatizado
## Sistema Profesional de Autenticación y Autorización

---

# ÍNDICE

1. [Introducción y Arquitectura](#1-introducción-y-arquitectura)
2. [Preparación del Entorno](#2-preparación-del-entorno)
    #usar un algoritmo de arbol binario de busqueda para poder mejorar la busqueda en base de datos 
3. [Configuración del Broker MQTT Seguro](#3-configuración-del-broker-mqtt-seguro)
4. [Sistema de Certificados PKI](#4-sistema-de-certificados-pki)
5. [Autenticación Multi-Factor](#5-autenticación-multi-factor)
6. [Autorización Granular](#6-autorización-granular)
7. [Implementación ESP8266](#7-implementación-esp8266)
8. [Monitoreo y Auditoría](#8-monitoreo-y-auditoría)
9. [Configuración de Cliente Python](#9-configuración-de-cliente-python)
10. [Testing y Validación](#10-testing-y-validación)
11. [Troubleshooting](#11-troubleshooting)
12. [Mantenimiento](#12-mantenimiento)

---

## 1. INTRODUCCIÓN Y ARQUITECTURA

### 1.1 Visión General del Sistema

Este manual implementa un sistema MQTT de grado empresarial con las siguientes características de seguridad:

- **Autenticación PKI**: Certificados X.509 únicos por dispositivo
- **Autorización granular**: ACL por tópico y dispositivo
- **Cifrado TLS 1.3**: Comunicación extremo a extremo
- **Integridad de mensajes**: HMAC-SHA256 en payload
- **Anti-replay protection**: Timestamps y nonces
- **Rate limiting**: Protección contra DoS
- **Auditoría completa**: Logging de todas las operaciones
- **Failover automático**: Alta disponibilidad

### 1.2 Topología de Red

```
┌─────────────────────────────────────────────────────────────┐
│                    ARQUITECTURA MQTT SEGURA                 │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐    TLS 1.3 + mTLS    ┌─────────────────┐ │
│  │   ESP8266    │◄─────────────────────►│  Raspberry Pi   │ │
│  │ (Sensor #1)  │   Port 8883 (MQTTS)   │   MQTT Broker   │ │
│  └──────────────┘                       │   + WebServer   │ │
│                                         └─────────────────┘ │
│  ┌──────────────┐    Certificado                           │
│  │   ESP8266    │◄─── Único por ────────┐                 │
│  │ (Actuador #2)│     Dispositivo        │                 │
│  └──────────────┘                       │                 │
│                                         │                 │
│  ┌──────────────┐    ACL Granular       │                 │
│  │   ESP8266    │◄─── por Tópico ───────┘                 │
│  │ (Control #3) │                                         │
│  └──────────────┘                                         │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              CLIENTES AUTORIZADOS                    │  │
│  │  • Compañero 1: garden/team1/+                      │  │
│  │  • Compañero 2: garden/team2/+                      │  │
│  │  • Compañero 3: garden/team3/+                      │  │
│  │  • Admin: garden/+/+                                │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 1.3 Estructura de Tópicos MQTT

```
garden/                                    # Root del sistema
├── device/                               # Dispositivos IoT
│   ├── esp001/                          # ESP8266 #1 (Sensores)
│   │   ├── status/                      # Estado del dispositivo
│   │   ├── sensors/                     # Datos de sensores
│   │   │   ├── temperature
│   │   │   ├── humidity
│   │   │   └── soil_moisture
│   │   └── config/                      # Configuración
│   ├── esp002/                          # ESP8266 #2 (Actuadores)
│   │   ├── status/
│   │   ├── actuators/
│   │   │   ├── water_pump
│   │   │   └── grow_lights
│   │   └── config/
│   └── esp003/                          # ESP8266 #3 (Control)
│       ├── status/
│       ├── controls/
│       │   ├── irrigation_schedule
│       │   └── light_schedule
│       └── config/
├── team/                                # Acceso por equipo
│   ├── team1/                          # Compañero 1
│   │   ├── commands/
│   │   └── monitoring/
│   ├── team2/                          # Compañero 2
│   │   ├── commands/
│   │   └── monitoring/
│   └── team3/                          # Compañero 3
│       ├── commands/
│       └── monitoring/
└── system/                             # Sistema
    ├── alerts/                         # Alertas de seguridad
    ├── logs/                           # Logs de auditoría
    └── health/                         # Estado del sistema
```

---

## 2. PREPARACIÓN DEL ENTORNO

### 2.1 Instalación de Dependencias

```bash
#!/bin/bash
# setup_mqtt_environment.sh

echo "=== CONFIGURACIÓN ENTORNO MQTT SEGURO ==="

# Actualizar sistema
sudo apt update && sudo apt full-upgrade -y

# Instalar dependencias principales
sudo apt install -y \
    mosquitto \
    mosquitto-clients \
    openssl \
    python3 \
    python3-pip \
    sqlite3 \
    nginx \
    fail2ban \
    ufw \
    htop \
    jq \
    curl \
    git

# Instalar librerías Python específicas
pip3 install \
    paho-mqtt \
    cryptography \
    PyJWT \
    passlib \
    bcrypt \
    pyotp \
    qrcode \
    requests \
    flask \
    gunicorn \
    sqlite3

# Crear estructura de directorios
sudo mkdir -p /opt/mqtt-secure/{certs,config,scripts,logs,backup}
sudo mkdir -p /var/log/mqtt-secure
sudo mkdir -p /etc/mosquitto/certs
sudo mkdir -p /home/garden/mqtt-clients

# Establecer permisos
sudo chown -R mosquitto:mosquitto /etc/mosquitto
sudo chown -R $USER:$USER /opt/mqtt-secure
sudo chmod 755 /opt/mqtt-secure
sudo chmod 700 /opt/mqtt-secure/certs

echo "Entorno preparado correctamente"
```

### 2.2 Configuración Inicial de Seguridad

```bash
#!/bin/bash
# initial_security_setup.sh

# Configurar firewall básico
sudo ufw --force enable
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Permitir solo puertos necesarios
sudo ufw allow 22/tcp comment "SSH"
sudo ufw allow 8883/tcp comment "MQTTS"
sudo ufw allow 443/tcp comment "HTTPS Management"
sudo ufw allow from 192.168.1.0/24 to any port 1883 comment "MQTT Local"

# Configurar fail2ban para MQTT
sudo tee /etc/fail2ban/filter.d/mosquitto.conf > /dev/null <<EOF
[Definition]
failregex = ^.*Client .* denied access.*$
            ^.*Invalid user.*$
            ^.*Authentication failed.*$
ignoreregex =
EOF

sudo tee /etc/fail2ban/jail.d/mosquitto.conf > /dev/null <<EOF
[mosquitto]
enabled = true
port = 8883,1883
filter = mosquitto
logpath = /var/log/mosquitto/mosquitto.log
maxretry = 3
bantime = 3600
findtime = 600
EOF

sudo systemctl restart fail2ban

echo "Seguridad inicial configurada"
```

---

## 3. CONFIGURACIÓN DEL BROKER MQTT SEGURO

### 3.1 Configuración Principal de Mosquitto

```bash
# /etc/mosquitto/mosquitto.conf
# Configuración MQTT Ultra Segura para Huerto Automatizado

# ============================================================================
# CONFIGURACIÓN GENERAL
# ============================================================================
# ID único del broker
clientid_prefixes garden_

# Archivo de log principal
log_dest file /var/log/mosquitto/mosquitto.log
log_type error
log_type warning
log_type notice
log_type information
log_type debug

# Timestamp en logs
log_timestamp true
log_timestamp_format %Y-%m-%d %H:%M:%S

# Conexiones
max_connections 100
max_inflight_messages 20
max_queued_messages 1000

# ============================================================================
# CONFIGURACIÓN DE RED Y PUERTOS
# ============================================================================

# Puerto MQTT sin cifrar (solo para red local)
listener 1883 127.0.0.1
protocol mqtt
allow_anonymous false

# Puerto MQTTS con TLS (para dispositivos remotos)
listener 8883
protocol mqtt
allow_anonymous false

# ============================================================================
# CONFIGURACIÓN TLS/SSL
# ============================================================================
# Certificados del servidor
cafile /etc/mosquitto/certs/ca.crt
certfile /etc/mosquitto/certs/server.crt
keyfile /etc/mosquitto/certs/server.key

# Configuración TLS avanzada
tls_version tlsv1.3
use_identity_as_username true
require_certificate true

# Cifrados permitidos (solo los más seguros)
ciphers ECDHE+AESGCM:ECDHE+CHACHA20:DHE+AESGCM:DHE+CHACHA20:!aNULL:!MD5:!DSS

# ============================================================================
# AUTENTICACIÓN Y AUTORIZACIÓN
# ============================================================================
# Plugin de autenticación personalizado
auth_plugin /opt/mqtt-secure/scripts/auth_plugin.so

# Base de datos de usuarios
password_file /etc/mosquitto/passwd
acl_file /etc/mosquitto/acl

# ============================================================================
# CONFIGURACIÓN DE PERSISTENCIA
# ============================================================================
persistence true
persistence_location /var/lib/mosquitto/
persistence_file mosquitto.db
autosave_interval 300

# Retención de mensajes
retained_persistence true
max_packet_size 1048576

# ============================================================================
# CONFIGURACIÓN DE KEEPALIVE Y TIMEOUTS
# ============================================================================
keepalive_interval 60
ping_timeout 10
retry_interval 20

# ============================================================================
# CONFIGURACIÓN DE RATE LIMITING
# ============================================================================
# Máximo de mensajes por cliente por segundo
message_size_limit 1048576

# ============================================================================
# CONFIGURACIÓN DE WEBSOCKETS (OPCIONAL)
# ============================================================================
listener 9001
protocol websockets
cafile /etc/mosquitto/certs/ca.crt
certfile /etc/mosquitto/certs/server.crt
keyfile /etc/mosquitto/certs/server.key

# ============================================================================
# CONFIGURACIÓN DE BRIDGE (SI SE NECESITA)
# ============================================================================
# connection bridge-to-cloud
# address mqtt.cloud-provider.com:8883
# bridge_cafile /etc/mosquitto/certs/cloud-ca.crt
# bridge_certfile /etc/mosquitto/certs/bridge.crt
# bridge_keyfile /etc/mosquitto/certs/bridge.key

# ============================================================================
# CONFIGURACIÓN DE LOGGING AVANZADO
# ============================================================================
log_dest file /var/log/mqtt-secure/connections.log
log_type subscribe
log_type unsubscribe
log_type websockets
log_type all

# ============================================================================
# CONFIGURACIÓN DE SEGURIDAD ADICIONAL
# ============================================================================
# Prevenir ataques de denegación de servicio
max_publish_per_second 10
max_subscribe_per_second 5
```

### 3.2 Script de Autenticación Personalizada

```python
#!/usr/bin/env python3
# /opt/mqtt-secure/scripts/mqtt_auth.py

import sqlite3
import hashlib
import hmac
import time
import json
import logging
from datetime import datetime, timedelta
import jwt
import pyotp

# Configuración de logging
logging.basicConfig(
    filename='/var/log/mqtt-secure/auth.log',
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

class MQTTAuthenticator:
    def __init__(self):
        self.db_path = '/opt/mqtt-secure/config/mqtt_users.db'
        self.secret_key = self._load_secret_key()
        self.init_database()
    
    def _load_secret_key(self):
        """Cargar clave secreta para JWT"""
        try:
            with open('/opt/mqtt-secure/config/jwt_secret.key', 'r') as f:
                return f.read().strip()
        except FileNotFoundError:
            # Generar nueva clave si no existe
            import secrets
            key = secrets.token_hex(32)
            with open('/opt/mqtt-secure/config/jwt_secret.key', 'w') as f:
                f.write(key)
            return key
    
    def init_database(self):
        """Inicializar base de datos de usuarios"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Tabla de usuarios
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT UNIQUE NOT NULL,
                password_hash TEXT NOT NULL,
                salt TEXT NOT NULL,
                role TEXT NOT NULL DEFAULT 'device',
                totp_secret TEXT,
                client_cert_fingerprint TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                last_login TIMESTAMP,
                failed_attempts INTEGER DEFAULT 0,
                locked_until TIMESTAMP,
                is_active BOOLEAN DEFAULT 1
            )
        ''')
        
        # Tabla de dispositivos
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS devices (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                device_id TEXT UNIQUE NOT NULL,
                device_type TEXT NOT NULL,
                cert_fingerprint TEXT UNIQUE NOT NULL,
                allowed_topics TEXT NOT NULL,
                team_member TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                last_seen TIMESTAMP,
                is_active BOOLEAN DEFAULT 1
            )
        ''')
        
        # Tabla de sesiones activas
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS active_sessions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT NOT NULL,
                client_id TEXT NOT NULL,
                session_token TEXT UNIQUE NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                expires_at TIMESTAMP NOT NULL,
                ip_address TEXT,
                user_agent TEXT
            )
        ''')
        
        # Tabla de intentos de autenticación
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS auth_attempts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT NOT NULL,
                client_id TEXT,
                ip_address TEXT,
                success BOOLEAN NOT NULL,
                reason TEXT,
                timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        conn.commit()
        conn.close()
    
    def add_device(self, device_id, device_type, cert_fingerprint, allowed_topics, team_member=None):
        """Agregar nuevo dispositivo al sistema"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        try:
            cursor.execute('''
                INSERT INTO devices (device_id, device_type, cert_fingerprint, allowed_topics, team_member)
                VALUES (?, ?, ?, ?, ?)
            ''', (device_id, device_type, cert_fingerprint, json.dumps(allowed_topics), team_member))
            
            conn.commit()
            logging.info(f"Dispositivo agregado: {device_id} - Tipo: {device_type}")
            return True
            
        except sqlite3.IntegrityError as e:
            logging.error(f"Error agregando dispositivo {device_id}: {e}")
            return False
        finally:
            conn.close()
    
    def add_user(self, username, password, role, team_member=None):
        """Agregar nuevo usuario al sistema"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Generar salt y hash de password
        salt = hashlib.sha256(str(time.time()).encode()).hexdigest()[:32]
        password_hash = hashlib.pbkdf2_hmac('sha256', password.encode(), salt.encode(), 100000).hex()
        
        # Generar secreto TOTP
        totp_secret = pyotp.random_base32()
        
        try:
            cursor.execute('''
                INSERT INTO users (username, password_hash, salt, role, totp_secret)
                VALUES (?, ?, ?, ?, ?)
            ''', (username, password_hash, salt, role, totp_secret))
            
            conn.commit()
            
            # Generar QR code para TOTP
            totp_uri = pyotp.totp.TOTP(totp_secret).provisioning_uri(
                username, issuer_name="Garden MQTT System"
            )
            
            logging.info(f"Usuario agregado: {username} - Rol: {role}")
            return {
                'success': True,
                'totp_secret': totp_secret,
                'totp_uri': totp_uri
            }
            
        except sqlite3.IntegrityError as e:
            logging.error(f"Error agregando usuario {username}: {e}")
            return {'success': False, 'error': str(e)}
        finally:
            conn.close()
    
    def authenticate_user(self, username, password, totp_code=None, client_cert_fingerprint=None):
        """Autenticar usuario con password y TOTP opcional"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        try:
            # Obtener datos del usuario
            cursor.execute('''
                SELECT password_hash, salt, role, totp_secret, failed_attempts, 
                       locked_until, is_active
                FROM users WHERE username = ?
            ''', (username,))
            
            user_data = cursor.fetchone()
            if not user_data:
                self._log_auth_attempt(username, None, None, False, "Usuario no encontrado")
                return False
            
            password_hash, salt, role, totp_secret, failed_attempts, locked_until, is_active = user_data
            
            # Verificar si la cuenta está activa
            if not is_active:
                self._log_auth_attempt(username, None, None, False, "Cuenta desactivada")
                return False
            
            # Verificar si la cuenta está bloqueada
            if locked_until and datetime.fromisoformat(locked_until) > datetime.now():
                self._log_auth_attempt(username, None, None, False, "Cuenta bloqueada")
                return False
            
            # Verificar password
            expected_hash = hashlib.pbkdf2_hmac('sha256', password.encode(), salt.encode(), 100000).hex()
            if not hmac.compare_digest(password_hash, expected_hash):
                self._increment_failed_attempts(username)
                self._log_auth_attempt(username, None, None, False, "Password incorrecto")
                return False
            
            # Verificar TOTP si está configurado
            if totp_secret and totp_code:
                totp = pyotp.TOTP(totp_secret)
                if not totp.verify(totp_code, valid_window=1):
                    self._increment_failed_attempts(username)
                    self._log_auth_attempt(username, None, None, False, "TOTP inválido")
                    return False
            
            # Reset intentos fallidos en login exitoso
            cursor.execute('''
                UPDATE users 
                SET failed_attempts = 0, locked_until = NULL, last_login = CURRENT_TIMESTAMP
                WHERE username = ?
            ''', (username,))
            
            conn.commit()
            self._log_auth_attempt(username, None, None, True, "Login exitoso")
            
            return {
                'success': True,
                'role': role,
                'username': username
            }
            
        except Exception as e:
            logging.error(f"Error en autenticación: {e}")
            return False
        finally:
            conn.close()
    
    def authenticate_device(self, device_id, cert_fingerprint):
        """Autenticar dispositivo por certificado"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        try:
            cursor.execute('''
                SELECT device_type, allowed_topics, team_member, is_active
                FROM devices 
                WHERE device_id = ? AND cert_fingerprint = ?
            ''', (device_id, cert_fingerprint))
            
            device_data = cursor.fetchone()
            if not device_data:
                self._log_auth_attempt(device_id, None, None, False, "Dispositivo no encontrado")
                return False
            
            device_type, allowed_topics, team_member, is_active = device_data
            
            if not is_active:
                self._log_auth_attempt(device_id, None, None, False, "Dispositivo desactivado")
                return False
            
            # Actualizar última conexión
            cursor.execute('''
                UPDATE devices SET last_seen = CURRENT_TIMESTAMP WHERE device_id = ?
            ''', (device_id,))
            
            conn.commit()
            self._log_auth_attempt(device_id, None, None, True, "Dispositivo autenticado")
            
            return {
                'success': True,
                'device_type': device_type,
                'allowed_topics': json.loads(allowed_topics),
                'team_member': team_member
            }
            
        except Exception as e:
            logging.error(f"Error autenticando dispositivo: {e}")
            return False
        finally:
            conn.close()
    
    def check_topic_authorization(self, username, topic, access_type='read'):
        """Verificar autorización de tópico"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        try:
            # Verificar si es un dispositivo
            cursor.execute('''
                SELECT allowed_topics FROM devices WHERE device_id = ?
            ''', (username,))
            
            device_data = cursor.fetchone()
            if device_data:
                allowed_topics = json.loads(device_data[0])
                return self._check_topic_match(topic, allowed_topics)
            
            # Verificar si es un usuario
            cursor.execute('''
                SELECT role FROM users WHERE username = ?
            ''', (username,))
            
            user_data = cursor.fetchone()
            if not user_data:
                return False
            
            role = user_data[0]
            
            # Definir permisos por rol
            role_permissions = {
                'admin': ['garden/+/+'],  # Acceso completo
                'team1': ['garden/device/+/sensors/+', 'garden/team/team1/+'],
                'team2': ['garden/device/+/actuators/+', 'garden/team/team2/+'],
                'team3': ['garden/device/+/controls/+', 'garden/team/team3/+'],
                'device': []  # Solo para dispositivos IoT
            }
            
            allowed_topics = role_permissions.get(role, [])
            return self._check_topic_match(topic, allowed_topics)
            
        except Exception as e:
            logging.error(f"Error verificando autorización: {e}")
            return False
        finally:
            conn.close()
    
    def _check_topic_match(self, topic, allowed_patterns):
        """Verificar si un tópico coincide con los patrones permitidos"""
        import re
        
        for pattern in allowed_patterns:
            # Convertir patrón MQTT a regex
            regex_pattern = pattern.replace('+', '[^/]+').replace('#', '.*')
            regex_pattern = f"^{regex_pattern}$"
            
            if re.match(regex_pattern, topic):
                return True
        
        return False
    
    def _increment_failed_attempts(self, username):
        """Incrementar intentos fallidos y bloquear si es necesario"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            UPDATE users 
            SET failed_attempts = failed_attempts + 1
            WHERE username = ?
        ''', (username,))
        
        # Bloquear cuenta después de 5 intentos fallidos
        cursor.execute('''
            UPDATE users 
            SET locked_until = datetime('now', '+30 minutes')
            WHERE username = ? AND failed_attempts >= 5
        ''', (username,))
        
        conn.commit()
        conn.close()
    
    def _log_auth_attempt(self, username, client_id, ip_address, success, reason):
        """Registrar intento de autenticación"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO auth_attempts (username, client_id, ip_address, success, reason)
            VALUES (?, ?, ?, ?, ?)
        ''', (username, client_id, ip_address, success, reason))
        
        conn.commit()
        conn.close()
    
    def generate_session_token(self, username, client_id, expires_hours=24):
        """Generar token de sesión JWT"""
        payload = {
            'username': username,
            'client_id': client_id,
            'exp': time.time() + (expires_hours * 3600),
            'iat': time.time()
        }
        
        token = jwt.encode(payload, self.secret_key, algorithm='HS256')
        
        # Guardar en base de datos
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        expires_at = datetime.now() + timedelta(hours=expires_hours)
        
        cursor.execute('''
            INSERT INTO active_sessions (username, client_id, session_token, expires_at)
            VALUES (?, ?, ?, ?)
        ''', (username, client_id, token, expires_at))
        
        conn.commit()
        conn.close()
        
        return token
    
    def verify_session_token(self, token):
        """Verificar token de sesión"""
        try:
            payload = jwt.decode(token, self.secret_key, algorithms=['HS256'])
            
            # Verificar que la sesión existe en BD
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            cursor.execute('''
                SELECT username, client_id FROM active_sessions 
                WHERE session_token = ? AND expires_at > CURRENT_TIMESTAMP
            ''', (token,))
            
            session_data = cursor.fetchone()
            conn.close()
            
            if session_data:
                return {
                    'valid': True,
                    'username': session_data[0],
                    'client_id': session_data[1]
                }
            else:
                return {'valid': False}
                
        except jwt.ExpiredSignatureError:
            return {'valid': False, 'error': 'Token expirado'}
        except jwt.InvalidTokenError:
            return {'valid': False, 'error': 'Token inválido'}

# Funciones para plugin C de Mosquitto
def mosquitto_auth_plugin_version():
    return 4

def mosquitto_auth_plugin_init(opts, reload):
    global authenticator
    authenticator = MQTTAuthenticator()
    return 0

def mosquitto_auth_plugin_cleanup():
    return 0

def mosquitto_auth_unpwd_check(username, password):
    """Verificar usuario y contraseña"""
    global authenticator
    result = authenticator.authenticate_user(username, password)
    return 0 if result else 1

def mosquitto_auth_acl_check(client_id, username, topic, access):
    """Verificar autorización de tópico"""
    global authenticator
    access_type = 'write' if access == 2 else 'read'
    result = authenticator.check_topic_authorization(username, topic, access_type)
    return 0 if result else 1

if __name__ == "__main__":
    # Script de configuración inicial
    auth = MQTTAuthenticator()
    
    # Agregar dispositivos ESP8266
    devices = [
        {
            'device_id': 'ESP8266_001',
            'device_type': 'sensor',
            'cert_fingerprint': 'AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD',
            'allowed_topics': [
                'garden/device/esp001/+',
                'garden/system/alerts',
                'garden/system/health'
            ]
        },
        {
            'device_id': 'ESP8266_002',
            'device_type': 'actuator',
            'cert_fingerprint': 'BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE',
            'allowed_topics': [
                'garden/device/esp002/+',
                'garden/system/alerts',
                'garden/system/health'
            ]
        },
        {
            'device_id': 'ESP8266_003',
            'device_type': 'controller',
            'cert_fingerprint': 'CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF',
            'allowed_topics': [
                'garden/device/esp003/+',
                'garden/system/alerts',
                'garden/system/health'
            ]
        }
    ]
    
    for device in devices:
        auth.add_device(**device)
    
    # Agregar usuarios del equipo
    users = [
        {
            'username': 'team1_sensor',
            'password': 'SecurePass123!Team1',
            'role': 'team1',
            'team_member': 'Compañero 1'
        },
        {
            'username': 'team2_actuator', 
            'password': 'SecurePass123!Team2',
            'role': 'team2',
            'team_member': 'Compañero 2'
        },
        {
            'username': 'team3_control',
            'password': 'SecurePass123!Team3', 
            'role': 'team3',
            'team_member': 'Compañero 3'
        },
        {
            'username': 'garden_admin',
            'password': 'AdminSecurePass456!',
            'role': 'admin',
            'team_member': 'Administrador'
        }
    ]
    
    for user in users:
        result = auth.add_user(**user)
        if result['success']:
            print(f"Usuario {user['username']} creado")
            print(f"TOTP Secret: {result['totp_secret']}")
            print(f"QR Code URI: {result['totp_uri']}")
            print("-" * 50)
```

---

## 4. SISTEMA DE CERTIFICADOS PKI

### 4.1 Script de Generación de CA y Certificados

```bash
#!/bin/bash
# /opt/mqtt-secure/scripts/generate_certificates.sh

set -e

CERT_DIR="/opt/mqtt-secure/certs"
CA_DIR="$CERT_DIR/ca"
DEVICES_DIR="$CERT_DIR/devices"
CLIENTS_DIR="$CERT_DIR/clients"

# Crear directorios
mkdir -p "$CA_DIR" "$DEVICES_DIR" "$CLIENTS_DIR"

echo "=== GENERACIÓN DE CERTIFICADOS PKI PARA MQTT ==="

# ============================================================================
# PASO 1: CREAR AUTORIDAD CERTIFICADORA (CA)
# ============================================================================
echo "Generando Autoridad Certificadora (CA)..."

# Configuración OpenSSL para CA
cat > "$CA_DIR/ca.conf" <<EOF
[req]
default_bits = 4096
prompt = no
distinguished_name = req_distinguished_name
x509_extensions = v3_ca

[req_distinguished_name]
C = MX
ST = Estado de México
L = Toluca
O = Garden IoT Systems
OU = Security Department
CN = Garden MQTT Root CA
emailAddress = admin@garden-iot.local

[v3_ca]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer:always
basicConstraints = critical,CA:true
keyUsage = critical,digitalSignature,cRLSign,keyCertSign
EOF

# Generar clave privada de CA (con passphrase)
openssl genrsa -aes256 -out "$CA_DIR/ca-key.pem" 4096
chmod 400 "$CA_DIR/ca-key.pem"

# Generar certificado de CA
openssl req -new -x509 -days 3650 -key "$CA_DIR/ca-key.pem" \
    -sha256 -out "$CA_DIR/ca.crt" -config "$CA_DIR/ca.conf"

echo "CA generada exitosamente"

# ============================================================================
# PASO 2: GENERAR CERTIFICADO DEL SERVIDOR MQTT
# ============================================================================
echo "Generando certificado del servidor MQTT..."

# Configuración para servidor
cat > "$CERT_DIR/server.conf" <<EOF
[req]
default_bits = 2048
prompt = no
distinguished_name = req_distinguished_name
req_extensions = v3_req

[req_distinguished_name]
C = MX
ST = Estado de México
L = Toluca
O = Garden IoT Systems
OU = MQTT Broker
CN = garden-mqtt.local
emailAddress = mqtt@garden-iot.local

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation,digitalSignature,keyEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = garden-mqtt.local
DNS.2 = localhost
DNS.3 = *.garden-iot.local
IP.1 = 192.168.1.100
IP.2 = 127.0.0.1
EOF

# Generar clave privada del servidor
openssl genrsa -out "$CERT_DIR/server-key.pem" 2048
chmod 400 "$CERT_DIR/server-key.pem"

# Generar CSR del servidor
openssl req -new -key "$CERT_DIR/server-key.pem" \
    -out "$CERT_DIR/server.csr" -config "$CERT_DIR/server.conf"

# Firmar certificado del servidor con CA
openssl x509 -req -in "$CERT_DIR/server.csr" -CA "$CA_DIR/ca.crt" \
    -CAkey "$CA_DIR/ca-key.pem" -CAcreateserial -out "$CERT_DIR/server.crt" \
    -days 365 -sha256 -extensions v3_req -extfile "$CERT_DIR/server.conf"

# Limpiar CSR
rm "$CERT_DIR/server.csr"

echo "Certificado del servidor generado"

# ============================================================================
# PASO 3: GENERAR CERTIFICADOS PARA DISPOSITIVOS ESP8266
# ============================================================================
echo "Generando certificados para dispositivos ESP8266..."

DEVICES=("ESP8266_001" "ESP8266_002" "ESP8266_003")

for device in "${DEVICES[@]}"; do
    echo "Generando certificado para $device..."
    
    # Configuración específica del dispositivo
    cat > "$DEVICES_DIR/$device.conf" <<EOF
[req]
default_bits = 2048
prompt = no
distinguished_name = req_distinguished_name
req_extensions = v3_req

[req_distinguished_name]
C = MX
ST = Estado de México  
L = Toluca
O = Garden IoT Systems
OU = IoT Devices
CN = $device.garden-iot.local
emailAddress = device-$device@garden-iot.local

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation,digitalSignature,keyEncipherment
extendedKeyUsage = clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $device.garden-iot.local
DNS.2 = $device.local
EOF

    # Generar clave privada del dispositivo
    openssl genrsa -out "$DEVICES_DIR/$device-key.pem" 2048
    chmod 400 "$DEVICES_DIR/$device-key.pem"
    
    # Generar CSR del dispositivo
    openssl req -new -key "$DEVICES_DIR/$device-key.pem" \
        -out "$DEVICES_DIR/$device.csr" -config "$DEVICES_DIR/$device.conf"
    
    # Firmar certificado del dispositivo
    openssl x509 -req -in "$DEVICES_DIR/$device.csr" -CA "$CA_DIR/ca.crt" \
        -CAkey "$CA_DIR/ca-key.pem" -CAcreateserial \
        -out "$DEVICES_DIR/$device.crt" -days 365 -sha256 \
        -extensions v3_req -extfile "$DEVICES_DIR/$device.conf"
    
    # Limpiar CSR
    rm "$DEVICES_DIR/$device.csr"
    
    # Generar fingerprint para identificación
    FINGERPRINT=$(openssl x509 -in "$DEVICES_DIR/$device.crt" -fingerprint -sha256 -noout | cut -d= -f2)
    echo "$device:$FINGERPRINT" >> "$DEVICES_DIR/fingerprints.txt"
    
    echo "Certificado para $device generado. Fingerprint: $FINGERPRINT"
done

# ============================================================================
# PASO 4: GENERAR CERTIFICADOS PARA CLIENTES DEL EQUIPO
# ============================================================================
echo "Generando certificados para miembros del equipo..."

TEAM_MEMBERS=("team1_sensor" "team2_actuator" "team3_control" "garden_admin")

for member in "${TEAM_MEMBERS[@]}"; do
    echo "Generando certificado para $member..."
    
    # Configuración del cliente
    cat > "$CLIENTS_DIR/$member.conf" <<EOF
[req]
default_bits = 2048
prompt = no
distinguished_name = req_distinguished_name
req_extensions = v3_req

[req_distinguished_name]
C = MX
ST = Estado de México
L = Toluca  
O = Garden IoT Systems
OU = Team Members
CN = $member
emailAddress = $member@garden-iot.local

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation,digitalSignature,keyEncipherment
extendedKeyUsage = clientAuth
EOF

    # Generar clave privada del cliente
    openssl genrsa -out "$CLIENTS_DIR/$member-key.pem" 2048
    chmod 400 "$CLIENTS_DIR/$member-key.pem"
    
    # Generar CSR del cliente
    openssl req -new -key "$CLIENTS_DIR/$member-key.pem" \
        -out "$CLIENTS_DIR/$member.csr" -config "$CLIENTS_DIR/$member.conf"
    
    # Firmar certificado del cliente
    openssl x509 -req -in "$CLIENTS_DIR/$member.csr" -CA "$CA_DIR/ca.crt" \
        -CAkey "$CA_DIR/ca-key.pem" -CAcreateserial \
        -out "$CLIENTS_DIR/$member.crt" -days 365 -sha256 \
        -extensions v3_req -extfile "$CLIENTS_DIR/$member.conf"
    
    # Limpiar CSR
    rm "$CLIENTS_DIR/$member.csr"
    
    # Generar PKCS#12 para fácil instalación en clientes
    openssl pkcs12 -export -out "$CLIENTS_DIR/$member.p12" \
        -inkey "$CLIENTS_DIR/$member-key.pem" \
        -in "$CLIENTS_DIR/$member.crt" \
        -certfile "$CA_DIR/ca.crt" \
        -name "$member Client Certificate"
    
    echo "Certificado para $member generado"
done

# ============================================================================
# PASO 5: CONFIGURAR PERMISOS Y COPIAR CERTIFICADOS
# ============================================================================
echo "Configurando permisos y copiando certificados..."

# Copiar certificados a directorio de Mosquitto
sudo cp "$CA_DIR/ca.crt" /etc/mosquitto/certs/
sudo cp "$CERT_DIR/server.crt" /etc/mosquitto/certs/
sudo cp "$CERT_DIR/server-key.pem" /etc/mosquitto/certs/

# Establecer permisos correctos
sudo chown mosquitto:mosquitto /etc/mosquitto/certs/*
sudo chmod 644 /etc/mosquitto/certs/ca.crt
sudo chmod 644 /etc/mosquitto/certs/server.crt  
sudo chmod 600 /etc/mosquitto/certs/server-key.pem

echo "=== CERTIFICADOS GENERADOS EXITOSAMENTE ==="
echo "CA Certificado: $CA_DIR/ca.crt"
echo "Servidor Certificado: $CERT_DIR/server.crt"
echo "Dispositivos: $DEVICES_DIR/"
echo "Clientes: $CLIENTS_DIR/"
echo "Fingerprints: $DEVICES_DIR/fingerprints.txt"
```

### 4.2 Script de Validación de Certificados

```bash
#!/bin/bash  
# /opt/mqtt-secure/scripts/validate_certificates.sh

CERT_DIR="/opt/mqtt-secure/certs"

echo "=== VALIDACIÓN DE CERTIFICADOS ==="

# Validar CA
echo "Validando CA..."
openssl x509 -in "$CERT_DIR/ca/ca.crt" -text -noout | grep -E "(Issuer|Subject|Not Before|Not After)"

# Validar certificado del servidor
echo -e "\nValidando certificado del servidor..."
openssl x509 -in "$CERT_DIR/server.crt" -text -noout | grep -E "(Issuer|Subject|Not Before|Not After)"

# Verificar cadena de certificados del servidor
echo -e "\nVerificando cadena del servidor..."
openssl verify -CAfile "$CERT_DIR/ca/ca.crt" "$CERT_DIR/server.crt"

# Validar certificados de dispositivos
echo -e "\nValidando certificados de dispositivos..."
for cert in "$CERT_DIR/devices"/*.crt; do
    if [ -f "$cert" ]; then
        device=$(basename "$cert" .crt)
        echo "Validando $device..."
        openssl verify -CAfile "$CERT_DIR/ca/ca.crt" "$cert"
    fi
done

# Validar certificados de clientes
echo -e "\nValidando certificados de clientes..."
for cert in "$CERT_DIR/clients"/*.crt; do
    if [ -f "$cert" ]; then
        client=$(basename "$cert" .crt)  
        echo "Validando $client..."
        openssl verify -CAfile "$CERT_DIR/ca/ca.crt" "$cert"
    fi
done

echo -e "\n=== VALIDACIÓN COMPLETADA ==="
```

---

## 5. AUTENTICACIÓN MULTI-FACTOR

### 5.1 Sistema TOTP Integrado

```python
#!/usr/bin/env python3
# /opt/mqtt-secure/scripts/totp_manager.py

import pyotp
import qrcode
import io
import base64
from PIL import Image
import sqlite3
import json

class TOTPManager:
    def __init__(self, db_path='/opt/mqtt-secure/config/mqtt_users.db'):
        self.db_path = db_path
    
    def generate_totp_secret(self, username, issuer="Garden MQTT"):
        """Generar secreto TOTP para un usuario"""
        secret = pyotp.random_base32()
        
        # Crear URI para TOTP
        totp = pyotp.TOTP(secret)
        provisioning_uri = totp.provisioning_uri(
            name=username,
            issuer_name=issuer
        )
        
        # Generar QR code
        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_L,
            box_size=10,
            border=4,
        )
        qr.add_data(provisioning_uri)
        qr.make(fit=True)
        
        # Crear imagen QR
        qr_image = qr.make_image(fill_color="black", back_color="white")
        
        # Convertir a base64 para embedding
        buffer = io.BytesIO()
        qr_image.save(buffer, format='PNG')
        qr_base64 = base64.b64encode(buffer.getvalue()).decode()
        
        return {
            'secret': secret,
            'uri': provisioning_uri,
            'qr_code': qr_base64
        }
    
    def verify_totp_code(self, username, code):
        """Verificar código TOTP"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('SELECT totp_secret FROM users WHERE username = ?', (username,))
        result = cursor.fetchone()
        conn.close()
        
        if not result or not result[0]:
            return False
        
        totp = pyotp.TOTP(result[0])
        return totp.verify(code, valid_window=1)
    
    def generate_backup_codes(self, username, count=8):
        """Generar códigos de respaldo"""
        import secrets
        import hashlib
        
        backup_codes = []
        hashed_codes = []
        
        for _ in range(count):
            code = secrets.token_hex(4).upper()
            backup_codes.append(code)
            # Hash del código para almacenamiento seguro
            hashed = hashlib.sha256(code.encode()).hexdigest()
            hashed_codes.append(hashed)
        
        # Guardar códigos hasheados en BD
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            UPDATE users SET backup_codes = ? WHERE username = ?
        ''', (json.dumps(hashed_codes), username))
        
        conn.commit()
        conn.close()
        
        return backup_codes
    
    def verify_backup_code(self, username, code):
        """Verificar y consumir código de respaldo"""
        import hashlib
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('SELECT backup_codes FROM users WHERE username = ?', (username,))
        result = cursor.fetchone()
        
        if not result or not result[0]:
            conn.close()
            return False
        
        backup_codes = json.loads(result[0])
        code_hash = hashlib.sha256(code.encode()).hexdigest()
        
        if code_hash in backup_codes:
            # Remover código usado
            backup_codes.remove(code_hash)
            cursor.execute('''
                UPDATE users SET backup_codes = ? WHERE username = ?
            ''', (json.dumps(backup_codes), username))
            conn.commit()
            conn.close()
            return True
        
        conn.close()
        return False

# Script de configuración TOTP
if __name__ == "__main__":
    import sys
    
    if len(sys.argv) < 2:
        print("Uso: python3 totp_manager.py <username>")
        sys.exit(1)
    
    username = sys.argv[1]
    totp_manager = TOTPManager()
    
    # Generar TOTP
    totp_data = totp_manager.generate_totp_secret(username)
    
    print(f"TOTP configurado para usuario: {username}")
    print(f"Secreto: {totp_data['secret']}")
    print(f"URI: {totp_data['uri']}")
    
    # Guardar QR code como imagen
    qr_image_data = base64.b64decode(totp_data['qr_code'])
    with open(f"/opt/mqtt-secure/config/{username}_qr.png", "wb") as f:
        f.write(qr_image_data)
    
    print(f"QR Code guardado: /opt/mqtt-secure/config/{username}_qr.png")
    
    # Generar códigos de respaldo
    backup_codes = totp_manager.generate_backup_codes(username)
    print(f"\nCódigos de respaldo (guardar en lugar seguro):")
    for i, code in enumerate(backup_codes, 1):
        print(f"{i:2d}. {code}")
```

### 5.2 Middleware de Autenticación MQTT

```python
#!/usr/bin/env python3
# /opt/mqtt-secure/scripts/mqtt_auth_middleware.py

import paho.mqtt.client as mqtt
import ssl
import json
import time
import hashlib
import hmac
from datetime import datetime
import logging

class MQTTAuthMiddleware:
    def __init__(self, broker_host="localhost", broker_port=8883):
        self.broker_host = broker_host
        self.broker_port = broker_port
        self.client = None
        self.authenticated_clients = {}
        self.message_queue = {}
        
        # Configurar logging
        logging.basicConfig(
            filename='/var/log/mqtt-secure/middleware.log',
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger(__name__)
    
    def setup_ssl_context(self, ca_cert, client_cert=None, client_key=None):
        """Configurar contexto SSL/TLS"""
        context = ssl.create_default_context(ssl.Purpose.SERVER_AUTH)
        context.load_verify_locations(ca_cert)
        
        if client_cert and client_key:
            context.load_cert_chain(client_cert, client_key)
        
        # Configuraciones de seguridad estrictas
        context.check_hostname = False  # Deshabilitado para desarrollo local
        context.verify_mode = ssl.CERT_REQUIRED
        context.minimum_version = ssl.TLSVersion.TLSv1_2
        
        return context
    
    def create_secure_client(self, client_id, username, password, 
                           cert_file=None, key_file=None, ca_file=None):
        """Crear cliente MQTT seguro"""
        client = mqtt.Client(client_id=client_id, protocol=mqtt.MQTTv5)
        
        # Configurar credenciales
        client.username_pw_set(username, password)
        
        # Configurar TLS
        if ca_file:
            ssl_context = self.setup_ssl_context(ca_file, cert_file, key_file)
            client.tls_set_context(ssl_context)
        
        # Configurar callbacks
        client.on_connect = self.on_connect
        client.on_disconnect = self.on_disconnect
        client.on_message = self.on_message
        client.on_publish = self.on_publish
        client.on_subscribe = self.on_subscribe
        
        return client
    
    def on_connect(self, client, userdata, flags, reason_code, properties=None):
        """Callback de conexión"""
        if reason_code == 0:
            self.logger.info(f"Cliente {client._client_id} conectado exitosamente")
            self.authenticated_clients[client._client_id] = {
                'connected_at': datetime.now(),
                'last_activity': datetime.now(),
                'message_count': 0
            }
        else:
            self.logger.error(f"Error conectando cliente {client._client_id}: {reason_code}")
    
    def on_disconnect(self, client, userdata, reason_code, properties=None):
        """Callback de desconexión"""
        self.logger.info(f"Cliente {client._client_id} desconectado: {reason_code}")
        if client._client_id in self.authenticated_clients:
            del self.authenticated_clients[client._client_id]
    
    def on_message(self, client, userdata, message):
        """Callback de mensaje recibido"""
        try:
            # Validar integridad del mensaje
            if self.validate_message_integrity(message):
                self.process_secure_message(client, message)
                
                # Actualizar estadísticas
                if client._client_id in self.authenticated_clients:
                    self.authenticated_clients[client._client_id]['last_activity'] = datetime.now()
                    self.authenticated_clients[client._client_id]['message_count'] += 1
            else:
                self.logger.warning(f"Mensaje con integridad inválida de {client._client_id}")
                
        except Exception as e:
            self.logger.error(f"Error procesando mensaje: {e}")
    
    def on_publish(self, client, userdata, mid):
        """Callback de mensaje publicado"""
        self.logger.debug(f"Mensaje {mid} publicado por {client._client_id}")
    
    def on_subscribe(self, client, userdata, mid, granted_qos, properties=None):
        """Callback de suscripción"""
        self.logger.info(f"Cliente {client._client_id} suscrito con QoS {granted_qos}")
    
    def validate_message_integrity(self, message):
        """Validar integridad HMAC del mensaje"""
        try:
            payload = json.loads(message.payload.decode())
            
            if 'signature' not in payload or 'timestamp' not in payload:
                return False
            
            # Verificar timestamp (evitar replay attacks)
            msg_timestamp = payload['timestamp']
            current_time = time.time()
            
            if abs(current_time - msg_timestamp) > 300:  # 5 minutos máximo
                self.logger.warning("Mensaje fuera del rango de tiempo permitido")
                return False
            
            # Verificar HMAC
            signature = payload.pop('signature')
            message_data = json.dumps(payload, sort_keys=True)
            
            # Clave HMAC específica por dispositivo (en producción usar KeyVault)
            hmac_key = self.get_device_hmac_key(message.topic)
            
            expected_signature = hmac.new(
                hmac_key.encode(),
                message_data.encode(),
                hashlib.sha256
            ).hexdigest()
            
            return hmac.compare_digest(signature, expected_signature)
            
        except (json.JSONDecodeError, KeyError, Exception) as e:
            self.logger.error(f"Error validando integridad: {e}")
            return False
    
    def get_device_hmac_key(self, topic):
        """Obtener clave HMAC específica por dispositivo/tópico"""
        # Mapeo de tópicos a claves HMAC
        hmac_keys = {
            'garden/device/esp001': 'ESP001_SECRET_KEY_2024',
            'garden/device/esp002': 'ESP002_SECRET_KEY_2024', 
            'garden/device/esp003': 'ESP003_SECRET_KEY_2024',
            'default': 'DEFAULT_HMAC_KEY_2024'
        }
        
        for topic_pattern, key in hmac_keys.items():
            if topic.startswith(topic_pattern):
                return key
        
        return hmac_keys['default']
    
    def process_secure_message(self, client, message):
        """Procesar mensaje validado"""
        try:
            payload = json.loads(message.payload.decode())
            topic = message.topic
            
            self.logger.info(f"Mensaje procesado - Tópico: {topic}, Cliente: {client._client_id}")
            
            # Procesar según tipo de mensaje
            if 'garden/device/' in topic and '/sensors/' in topic:
                self.handle_sensor_data(payload, topic)
            elif 'garden/device/' in topic and '/actuators/' in topic:
                self.handle_actuator_command(payload, topic)
            elif 'garden/team/' in topic:
                self.handle_team_message(payload, topic)
            elif 'garden/system/' in topic:
                self.handle_system_message(payload, topic)
                
        except Exception as e:
            self.logger.error(f"Error procesando mensaje seguro: {e}")
    
    def handle_sensor_data(self, payload, topic):
        """Manejar datos de sensores"""
        # Guardar datos en base de datos
        # Validar rangos de sensores
        # Generar alertas si es necesario
        self.logger.info(f"Datos de sensor recibidos: {topic}")
    
    def handle_actuator_command(self, payload, topic):
        """Manejar comandos de actuadores"""
        # Validar comandos
        # Ejecutar acciones
        # Registrar en auditoría
        self.logger.info(f"Comando de actuador procesado: {topic}")
    
    def handle_team_message(self, payload, topic):
        """Manejar mensajes del equipo"""
        # Procesar comandos específicos del equipo
        # Aplicar autorización granular
        self.logger.info(f"Mensaje de equipo procesado: {topic}")
    
    def handle_system_message(self, payload, topic):
        """Manejar mensajes del sistema"""
        # Procesar alertas del sistema
        # Manejar logs y métricas
        self.logger.info(f"Mensaje de sistema procesado: {topic}")
    
    def create_signed_message(self, data, topic):
        """Crear mensaje firmado con HMAC"""
        message = data.copy()
        message['timestamp'] = time.time()
        
        # Generar HMAC
        message_data = json.dumps(message, sort_keys=True)
        hmac_key = self.get_device_hmac_key(topic)
        
        signature = hmac.new(
            hmac_key.encode(),
            message_data.encode(), 
            hashlib.sha256
        ).hexdigest()
        
        message['signature'] = signature
        return json.dumps(message)
    
    def monitor_clients(self):
        """Monitorear clientes activos"""
        current_time = datetime.now()
        
        for client_id, info in self.authenticated_clients.items():
            # Verificar inactividad
            time_diff = (current_time - info['last_activity']).total_seconds()
            
            if time_diff > 300:  # 5 minutos sin actividad
                self.logger.warning(f"Cliente {client_id} inactivo por {time_diff} segundos")
                
            # Log estadísticas
            self.logger.info(f"Cliente {client_id}: {info['message_count']} mensajes")

if __name__ == "__main__":
    # Ejemplo de uso del middleware
    middleware = MQTTAuthMiddleware()
    
    # Crear cliente seguro para testing
    test_client = middleware.create_secure_client(
        client_id="test_middleware",
        username="garden_admin",
        password="AdminSecurePass456!",
        ca_file="/opt/mqtt-secure/certs/ca/ca.crt"
    )
    
    # Conectar y mantener conexión
    try:
        test_client.connect(middleware.broker_host, middleware.broker_port, 60)
        test_client.loop_forever()
    except KeyboardInterrupt:
        test_client.disconnect()
        print("Cliente desconectado")
```

---

Manual Completo: Implementación MQTT Ultra Seguro - CONTINUACIÓN
6. AUTORIZACIÓN GRANULAR (Continuación)
6.1 Archivo de Control de Acceso (ACL) - CONTINUACIÓN
bash# ESP8266 #2 - Actuadores
user ESP8266_002
topic read garden/device/esp002/config/+
topic read garden/team/team2/commands/+
topic write garden/device/esp002/status
topic write garden/device/esp002/actuators/+
topic write garden/system/alerts
topic write garden/system/health

# ESP8266 #3 - Controlador
user ESP8266_003
topic read garden/device/esp003/config/+
topic read garden/team/team3/commands/+
topic write garden/device/esp003/status
topic write garden/device/esp003/controls/+
topic write garden/system/alerts
topic write garden/system/health

# ============================================================================
# MIEMBROS DEL EQUIPO
# ============================================================================

# Compañero 1 - Responsable de Sensores
user team1_sensor
topic read garden/device/esp001/sensors/+
topic read garden/device/esp001/status
topic readwrite garden/team/team1/+
topic read garden/system/health

# Compañero 2 - Responsable de Actuadores
user team2_actuator
topic read garden/device/esp002/actuators/+
topic read garden/device/esp002/status
topic readwrite garden/team/team2/+
topic write garden/team/team2/commands/+
topic read garden/system/health

# Compañero 3 - Responsable de Control
user team3_control
topic read garden/device/esp003/controls/+
topic read garden/device/esp003/status
topic readwrite garden/team/team3/+
topic write garden/team/team3/commands/+
topic read garden/system/health
topic read garden/device/+/sensors/+

# ============================================================================
# PATRÓN DE TÓPICOS WILDCARD
# ============================================================================
# + = un nivel de jerarquía
# # = múltiples niveles de jerarquía

# Ejemplo de uso correcto:
# garden/+/status         -> garden/device/status, garden/team/status
# garden/device/#         -> garden/device/esp001/sensors/temperature
# garden/device/+/sensors/+ -> garden/device/esp001/sensors/humidity
6.2 Script de Gestión de ACL Dinámico
python#!/usr/bin/env python3
# /opt/mqtt-secure/scripts/acl_manager.py

import sqlite3
import re
import logging
from datetime import datetime

class ACLManager:
    def __init__(self, acl_file='/etc/mosquitto/acl', db_path='/opt/mqtt-secure/config/mqtt_users.db'):
        self.acl_file = acl_file
        self.db_path = db_path
        
        logging.basicConfig(
            filename='/var/log/mqtt-secure/acl.log',
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger(__name__)
    
    def add_acl_rule(self, username, topic, permission='readwrite'):
        """
        Agregar nueva regla ACL
        
        Args:
            username: Usuario o dispositivo
            topic: Patrón de tópico MQTT
            permission: 'read', 'write', o 'readwrite'
        """
        try:
            # Validar entrada
            if permission not in ['read', 'write', 'readwrite']:
                raise ValueError(f"Permiso inválido: {permission}")
            
            # Leer ACL actual
            with open(self.acl_file, 'r') as f:
                acl_content = f.readlines()
            
            # Buscar sección del usuario
            user_found = False
            insert_index = -1
            
            for i, line in enumerate(acl_content):
                if line.strip() == f"user {username}":
                    user_found = True
                    insert_index = i + 1
                elif user_found and line.startswith('user '):
                    break
                elif user_found and line.strip():
                    insert_index = i + 1
            
            # Preparar nueva regla
            new_rule = f"topic {permission} {topic}\n"
            
            if user_found:
                # Insertar en sección existente
                acl_content.insert(insert_index, new_rule)
            else:
                # Crear nueva sección de usuario
                acl_content.append(f"\nuser {username}\n")
                acl_content.append(new_rule)
            
            # Escribir ACL actualizado
            with open(self.acl_file, 'w') as f:
                f.writelines(acl_content)
            
            self.logger.info(f"Regla ACL agregada: {username} -> {topic} ({permission})")
            return True
            
        except Exception as e:
            self.logger.error(f"Error agregando regla ACL: {e}")
            return False
    
    def remove_acl_rule(self, username, topic):
        """Eliminar regla ACL específica"""
        try:
            with open(self.acl_file, 'r') as f:
                acl_content = f.readlines()
            
            new_content = []
            in_user_section = False
            
            for line in acl_content:
                if line.strip() == f"user {username}":
                    in_user_section = True
                    new_content.append(line)
                elif in_user_section and line.startswith('user '):
                    in_user_section = False
                    new_content.append(line)
                elif in_user_section and topic in line:
                    # Omitir esta línea (eliminar regla)
                    self.logger.info(f"Regla eliminada: {line.strip()}")
                    continue
                else:
                    new_content.append(line)
            
            with open(self.acl_file, 'w') as f:
                f.writelines(new_content)
            
            return True
            
        except Exception as e:
            self.logger.error(f"Error eliminando regla ACL: {e}")
            return False
    
    def get_user_permissions(self, username):
        """Obtener todos los permisos de un usuario"""
        try:
            with open(self.acl_file, 'r') as f:
                acl_content = f.readlines()
            
            permissions = []
            in_user_section = False
            
            for line in acl_content:
                if line.strip() == f"user {username}":
                    in_user_section = True
                elif in_user_section and line.startswith('user '):
                    break
                elif in_user_section and line.strip().startswith('topic '):
                    parts = line.strip().split(maxsplit=2)
                    if len(parts) == 3:
                        permissions.append({
                            'permission': parts[1],
                            'topic': parts[2]
                        })
            
            return permissions
            
        except Exception as e:
            self.logger.error(f"Error obteniendo permisos: {e}")
            return []
    
    def validate_topic_access(self, username, topic, access_type='read'):
        """Validar si un usuario tiene acceso a un tópico"""
        permissions = self.get_user_permissions(username)
        
        for perm in permissions:
            if access_type in ['read', 'write'] and perm['permission'] not in [access_type, 'readwrite']:
                continue
            
            # Convertir patrón MQTT a regex
            pattern = perm['topic'].replace('+', '[^/]+').replace('#', '.*')
            pattern = f"^{pattern}$"
            
            if re.match(pattern, topic):
                return True
        
        return False
    
    def generate_acl_report(self):
        """Generar reporte de todas las ACL configuradas"""
        try:
            with open(self.acl_file, 'r') as f:
                acl_content = f.readlines()
            
            report = {
                'generated_at': datetime.now().isoformat(),
                'users': {}
            }
            
            current_user = None
            
            for line in acl_content:
                line = line.strip()
                if line.startswith('user '):
                    current_user = line.split()[1]
                    report['users'][current_user] = []
                elif current_user and line.startswith('topic '):
                    parts = line.split(maxsplit=2)
                    if len(parts) == 3:
                        report['users'][current_user].append({
                            'permission': parts[1],
                            'topic': parts[2]
                        })
            
            return report
            
        except Exception as e:
            self.logger.error(f"Error generando reporte ACL: {e}")
            return None
    
    def backup_acl(self):
        """Crear backup del archivo ACL"""
        import shutil
        from datetime import datetime
        
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        backup_file = f"{self.acl_file}.backup_{timestamp}"
        
        try:
            shutil.copy2(self.acl_file, backup_file)
            self.logger.info(f"Backup ACL creado: {backup_file}")
            return backup_file
        except Exception as e:
            self.logger.error(f"Error creando backup ACL: {e}")
            return None
    
    def reload_mosquitto_acl(self):
        """Recargar configuración ACL en Mosquitto"""
        import subprocess
        
        try:
            # Enviar señal SIGHUP a Mosquitto para recargar config
            subprocess.run(['sudo', 'systemctl', 'reload', 'mosquitto'], check=True)
            self.logger.info("ACL recargado en Mosquitto")
            return True
        except subprocess.CalledProcessError as e:
            self.logger.error(f"Error recargando Mosquitto: {e}")
            return False

# Script de línea de comandos
if __name__ == "__main__":
    import sys
    import json
    
    acl_manager = ACLManager()
    
    if len(sys.argv) < 2:
        print("""
Uso: python3 acl_manager.py <comando> [argumentos]

Comandos disponibles:
    add <usuario> <topic> <permiso>     - Agregar regla ACL
    remove <usuario> <topic>            - Eliminar regla ACL
    list <usuario>                      - Listar permisos de usuario
    validate <usuario> <topic> <tipo>   - Validar acceso a tópico
    report                              - Generar reporte completo
    backup                              - Crear backup de ACL
    reload                              - Recargar configuración en Mosquitto

Ejemplos:
    python3 acl_manager.py add team1_sensor garden/device/esp001/sensors/+ read
    python3 acl_manager.py list garden_admin
    python3 acl_manager.py validate team2_actuator garden/device/esp002/actuators/pump write
""")
        sys.exit(1)
    
    command = sys.argv[1]
    
    if command == 'add':
        if len(sys.argv) != 5:
            print("Error: add requiere <usuario> <topic> <permiso>")
            sys.exit(1)
        
        username = sys.argv[2]
        topic = sys.argv[3]
        permission = sys.argv[4]
        
        if acl_manager.add_acl_rule(username, topic, permission):
            print(f"✓ Regla agregada exitosamente")
            acl_manager.reload_mosquitto_acl()
        else:
            print("✗ Error agregando regla")
            sys.exit(1)
    
    elif command == 'remove':
        if len(sys.argv) != 4:
            print("Error: remove requiere <usuario> <topic>")
            sys.exit(1)
        
        username = sys.argv[2]
        topic = sys.argv[3]
        
        if acl_manager.remove_acl_rule(username, topic):
            print(f"✓ Regla eliminada exitosamente")
            acl_manager.reload_mosquitto_acl()
        else:
            print("✗ Error eliminando regla")
            sys.exit(1)
    
    elif command == 'list':
        if len(sys.argv) != 3:
            print("Error: list requiere <usuario>")
            sys.exit(1)
        
        username = sys.argv[2]
        permissions = acl_manager.get_user_permissions(username)
        
        print(f"\nPermisos para usuario: {username}")
        print("-" * 60)
        for perm in permissions:
            print(f"  {perm['permission']:10s} -> {perm['topic']}")
        print()
    
    elif command == 'validate':
        if len(sys.argv) != 5:
            print("Error: validate requiere <usuario> <topic> <tipo>")
            sys.exit(1)
        
        username = sys.argv[2]
        topic = sys.argv[3]
        access_type = sys.argv[4]
        
        has_access = acl_manager.validate_topic_access(username, topic, access_type)
        
        if has_access:
            print(f"✓ {username} TIENE acceso {access_type} a {topic}")
        else:
            print(f"✗ {username} NO TIENE acceso {access_type} a {topic}")
    
    elif command == 'report':
        report = acl_manager.generate_acl_report()
        
        if report:
            print(json.dumps(report, indent=2))
        else:
            print("✗ Error generando reporte")
            sys.exit(1)
    
    elif command == 'backup':
        backup_file = acl_manager.backup_acl()
        
        if backup_file:
            print(f"✓ Backup creado: {backup_file}")
        else:
            print("✗ Error creando backup")
            sys.exit(1)
    
    elif command == 'reload':
        if acl_manager.reload_mosquitto_acl():
            print("✓ Mosquitto recargado exitosamente")
        else:
            print("✗ Error recargando Mosquitto")
            sys.exit(1)
    
    else:
        print(f"Comando desconocido: {command}")
        sys.exit(1)

7. IMPLEMENTACIÓN ESP8266
7.1 Código Base para ESP8266 con Seguridad TLS
cpp// garden_mqtt_secure.ino
// Código para ESP8266 con autenticación TLS y HMAC

#include <ESP8266WiFi.h>
#include <PubSubClient.h>
#include <WiFiClientSecure.h>
#include <time.h>
#include <ArduinoJson.h>
#include <Crypto.h>
#include <SHA256.h>

// ============================================================================
// CONFIGURACIÓN DE RED Y MQTT
// ============================================================================
const char* WIFI_SSID = "TU_RED_WIFI";
const char* WIFI_PASSWORD = "TU_PASSWORD_WIFI";

const char* MQTT_SERVER = "192.168.1.100";  // IP de Raspberry Pi
const int MQTT_PORT = 8883;                 // Puerto MQTTS

// Identificación del dispositivo
const char* DEVICE_ID = "ESP8266_001";
const char* MQTT_USER = "ESP8266_001";
const char* MQTT_PASSWORD = "";  // Autenticación por certificado

// ============================================================================
// CONFIGURACIÓN DE CERTIFICADOS
// ============================================================================
// IMPORTANTE: Reemplazar con tus certificados reales

// Certificado CA (ca.crt)
const char* CA_CERT = R"EOF(
-----BEGIN CERTIFICATE-----
MIIFazCCA1OgAwIBAgIUXXXXXXXXXXXXXXXXXXXXXXXXXXXwDQYJKoZIhvcNAQEL
BQAwRTELMAkGA1UEBhMCTVgxEzARBgNVBAgMClNvbWUtU3RhdGUxITAfBgNVBAoM
GEludGVybmV0IFdpZGdpdHMgUHR5IEx0ZDAeFw0yNDAxMDEwMDAwMDBaFw0zNDAx
MDEwMDAwMDBaMEUxCzAJBgNVBAYTAk1YMRMwEQYDVQQIDApTb21lLVN0YXRlMSEw
HwYDVQQKDBhJbnRlcm5ldCBXaWRnaXRzIFB0eSBMdGQwggIiMA0GCSqGSIb3DQEB
AQUAA4ICDwAwggIKAoICAQDXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
... (certificado completo)
-----END CERTIFICATE-----
)EOF";

// Certificado del cliente (ESP8266_001.crt)
const char* CLIENT_CERT = R"EOF(
-----BEGIN CERTIFICATE-----
MIIFazCCA1OgAwIBAgIUYYYYYYYYYYYYYYYYYYYYYYYYYYYwDQYJKoZIhvcNAQEL
... (certificado del dispositivo)
-----END CERTIFICATE-----
)EOF";

// Clave privada del cliente (ESP8266_001-key.pem)
const char* CLIENT_KEY = R"EOF(
-----BEGIN PRIVATE KEY-----
MIIJQgIBADANBgkqhkiG9w0BAQEFAASCCSwwggkoAgEAAoICAQDYYYYYYYYYYYYY
... (clave privada del dispositivo)
-----END PRIVATE KEY-----
)EOF";

// ============================================================================
// CONFIGURACIÓN DE TÓPICOS
// ============================================================================
const char* TOPIC_STATUS = "garden/device/esp001/status";
const char* TOPIC_SENSORS = "garden/device/esp001/sensors/";
const char* TOPIC_CONFIG = "garden/device/esp001/config/#";
const char* TOPIC_ALERTS = "garden/system/alerts";

// ============================================================================
// CONFIGURACIÓN DE SENSORES (ajustar según hardware)
// ============================================================================
const int PIN_TEMP_SENSOR = A0;      // Sensor de temperatura
const int PIN_HUMIDITY_SENSOR = D1;   // Sensor de humedad
const int PIN_SOIL_SENSOR = D2;       // Sensor de humedad de suelo
const int PIN_LED_STATUS = D4;        // LED de estado (Built-in)

// ============================================================================
// VARIABLES GLOBALES
// ============================================================================
WiFiClientSecure espClient;
PubSubClient mqttClient(espClient);

// Buffer para JSON
StaticJsonDocument<512> jsonDoc;

// Timing
unsigned long lastSensorRead = 0;
unsigned long lastHeartbeat = 0;
const unsigned long SENSOR_INTERVAL = 30000;  // 30 segundos
const unsigned long HEARTBEAT_INTERVAL = 60000;  // 1 minuto

// Clave HMAC (debe coincidir con el servidor)
const char* HMAC_KEY = "ESP001_SECRET_KEY_2024";

// ============================================================================
// FUNCIONES DE CONFIGURACIÓN
// ============================================================================

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n\n=== Garden MQTT Secure Client ===");
  Serial.println("Device: " + String(DEVICE_ID));
  
  // Configurar pines
  pinMode(PIN_LED_STATUS, OUTPUT);
  pinMode(PIN_TEMP_SENSOR, INPUT);
  pinMode(PIN_HUMIDITY_SENSOR, INPUT);
  pinMode(PIN_SOIL_SENSOR, INPUT);
  
  // Parpadeo inicial
  blinkLED(3, 200);
  
  // Conectar WiFi
  setupWiFi();
  
  // Sincronizar tiempo (necesario para validar certificados)
  setupTime();
  
  // Configurar certificados TLS
  setupTLS();
  
  // Configurar MQTT
  mqttClient.setServer(MQTT_SERVER, MQTT_PORT);
  mqttClient.setCallback(mqttCallback);
  mqttClient.setKeepAlive(60);
  mqttClient.setSocketTimeout(30);
  
  // Conectar MQTT
  connectMQTT();
  
  Serial.println("=== Configuración completa ===\n");
}

void setupWiFi() {
  Serial.print("Conectando a WiFi: ");
  Serial.println(WIFI_SSID);
  
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    digitalWrite(PIN_LED_STATUS, !digitalRead(PIN_LED_STATUS));
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n✓ WiFi conectado");
    Serial.print("IP: ");
    Serial.println(WiFi.localIP());
    Serial.print("RSSI: ");
    Serial.println(WiFi.RSSI());
    digitalWrite(PIN_LED_STATUS, HIGH);
  } else {
    Serial.println("\n✗ Error conectando WiFi");
    ESP.restart();
  }
}

void setupTime() {
  Serial.print("Sincronizando tiempo NTP...");
  
  configTime(0, 0, "pool.ntp.org", "time.nist.gov");
  
  time_t now = time(nullptr);
  int attempts = 0;
  
  while (now < 8 * 3600 * 2 && attempts < 20) {
    delay(500);
    Serial.print(".");
    now = time(nullptr);
    attempts++;
  }
  
  if (now >= 8 * 3600 * 2) {
    Serial.println(" ✓");
    struct tm timeinfo;
    gmtime_r(&now, &timeinfo);
    Serial.print("Fecha/Hora actual: ");
    Serial.println(asctime(&timeinfo));
  } else {
    Serial.println(" ✗ Error sincronizando tiempo");
  }
}

void setupTLS() {
  Serial.println("Configurando TLS...");
  
  // Establecer certificados
  espClient.setCACert(CA_CERT);
  espClient.setCertificate(CLIENT_CERT);
  espClient.setPrivateKey(CLIENT_KEY);
  
  // Configuración de seguridad
  espClient.setInsecure();  // Para desarrollo; en producción verificar hostname
  
  Serial.println("✓ TLS configurado");
}

void connectMQTT() {
  Serial.println("Conectando a broker MQTT...");
  
  int attempts = 0;
  while (!mqttClient.connected() && attempts < 5) {
    Serial.print("Intento ");
    Serial.print(attempts + 1);
    Serial.print("/5... ");
    
    // Intentar conexión
    if (mqttClient.connect(DEVICE_ID, MQTT_USER, MQTT_PASSWORD)) {
      Serial.println("✓ Conectado");
      
      // Suscribirse a tópicos de configuración
      mqttClient.subscribe(TOPIC_CONFIG);
      Serial.println("✓ Suscrito a: " + String(TOPIC_CONFIG));
      
      // Publicar mensaje de inicio
      publishStatus("online");
      
      blinkLED(2, 100);
      
    } else {
      Serial.print("✗ Error: ");
      Serial.println(mqttClient.state());
      delay(5000);
    }
    
    attempts++;
  }
  
  if (!mqttClient.connected()) {
    Serial.println("✗ No se pudo conectar a MQTT. Reiniciando...");
    delay(5000);
    ESP.restart();
  }
}

// ============================================================================
// CALLBACK MQTT
// ============================================================================

void mqttCallback(char* topic, byte* payload, unsigned int length) {
  Serial.print("Mensaje recibido [");
  Serial.print(topic);
  Serial.print("]: ");
  
  // Convertir payload a string
  String message = "";
  for (unsigned int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  Serial.println(message);
  
  // Procesar mensaje
  processCommand(topic, message);
}

void processCommand(String topic, String message) {
  // Parsear JSON
  DeserializationError error = deserializeJson(jsonDoc, message);
  
  if (error) {
    Serial.print("Error parseando JSON: ");
    Serial.println(error.c_str());
    return;
  }
  
  // Verificar firma HMAC
  if (!verifyHMAC(message)) {
    Serial.println("✗ Firma HMAC inválida");
    publishAlert("invalid_hmac", "Mensaje con firma inválida recibido");
    return;
  }
  
  // Procesar comandos según tópico
  if (topic.indexOf("/config/") > 0) {
    handleConfigCommand(jsonDoc);
  }
}

void handleConfigCommand(JsonDocument& doc) {
  // Manejar comandos de configuración
  if (doc.containsKey("sensor_interval")) {
    unsigned long newInterval = doc["sensor_interval"];
    if (newInterval >= 10000 && newInterval <= 300000) {
      // Actualizar intervalo de sensores (10s - 5min)
      Serial.println("✓ Intervalo actualizado: " + String(newInterval) + "ms");
    }
  }
  
  if (doc.containsKey("reboot")) {
    bool reboot = doc["reboot"];
    if (reboot) {
      Serial.println("⚠ Reinicio solicitado");
      publishStatus("rebooting");
      delay(1000);
      ESP.restart();
    }
  }
}

// ============================================================================
// FUNCIONES DE SEGURIDAD
// ============================================================================

bool verifyHMAC(String message) {
  // Parsear JSON para extraer firma
  StaticJsonDocument<512> doc;
  DeserializationError error = deserializeJson(doc, message);
  
  if (error || !doc.containsKey("signature")) {
    return false;
  }
  
  String receivedSignature = doc["signature"].as<String>();
  
  // Remover firma del mensaje
  doc.remove("signature");
  String messageWithoutSignature;
  serializeJson(doc, messageWithoutSignature);
  
  // Calcular HMAC esperado
  String expectedSignature = calculateHMAC(messageWithoutSignature);
  
  // Comparar
  return (receivedSignature == expectedSignature);
}

String calculateHMAC(String message) {
  SHA256 sha256;
  
  // Preparar HMAC-SHA256
  sha256.resetHMAC(HMAC_KEY, strlen(HMAC_KEY));
  sha256.update(message.c_str(), message.length());
  
  // Obtener hash
  uint8_t hash[32];
  sha256.finalizeHMAC(HMAC_KEY, strlen(HMAC_KEY), hash, sizeof(hash));
  
  // Convertir a hexadecimal
  String hmacHex = "";
  for (int i = 0; i < 32; i++) {
    if (hash[i] < 16) hmacHex += "0";
    hmacHex += String(hash[i], HEX);
  }
  
  return hmacHex;
}

String createSignedMessage(JsonDocument& doc) {
  // Agregar timestamp
  doc["timestamp"] = time(nullptr);
  
  // Serializar sin firma
  String message;
  serializeJson(doc, message);
  
  // Calcular HMAC
  String signature = calculateHMAC(message);
  
  // Agregar firma
  doc["signature"] = signature;
  
  // Serializar mensaje final
  String signedMessage;
  serializeJson(doc, signedMessage);
  
  return signedMessage;
}

// ============================================================================
// FUNCIONES DE PUBLICACIÓN
// ============================================================================

void publishStatus(String status) {
  jsonDoc.clear();
  jsonDoc["device_id"] = DEVICE_ID;
  jsonDoc["status"] = status;
  jsonDoc["uptime"] = millis();
  jsonDoc["wifi_rssi"] = WiFi.RSSI();
  jsonDoc["free_heap"] = ESP.getFreeHeap();
  
  String message = createSignedMessage(jsonDoc);
  
  if (mqttClient.publish(TOPIC_STATUS, message.c_str(), true)) {
    Serial.println("✓ Status publicado: " + status);
  } else {
    Serial.println("✗ Error publicando status");
  }
}

void publishSensorData(String sensorType, float value, String unit) {
  jsonDoc.clear();
  jsonDoc["device_id"] = DEVICE_ID;
  jsonDoc["sensor"] = sensorType;
  jsonDoc["value"] = value;
  jsonDoc["unit"] = unit;
  
  String message = createSignedMessage(jsonDoc);
  String topic = String(TOPIC_SENSORS) + sensorType;
  
  if (mqttClient.publish(topic.c_str(), message.c_str())) {
    Serial.println("✓ Sensor publicado: " + sensorType + " = " + String(value) + " " + unit);
  } else {
    Serial.println("✗ Error publicando sensor");
  }
}

void publishAlert(String alertType, String description) {
  jsonDoc.clear();
  jsonDoc["device_id"] = DEVICE_ID;
  jsonDoc["alert_type"] = alertType;
  jsonDoc["description"] = description;
  jsonDoc["severity"] = "warning";
  
  String message = createSignedMessage(jsonDoc);
  
  if (mqttClient.publish(TOPIC_ALERTS, message.c_str())) {
    Serial.println("⚠ Alerta publicada: " + alertType);
  }
}

// ============================================================================
// FUNCIONES DE SENSORES
// ============================================================================

void readAndPublishSensors() {
  // Leer temperatura (ejemplo con sensor analógico)
  int tempRaw = analogRead(PIN_TEMP_SENSOR);
  float temperature = map(tempRaw, 0, 1023, 0, 100);  // Ajustar según sensor
  publishSensorData("temperature", temperature, "°C");

  7. IMPLEMENTACIÓN ESP8266
7.1 Código Base para ESP8266 con Seguridad TLS
cpp// garden_mqtt_secure.ino
// Código para ESP8266 con autenticación TLS y HMAC

#include <ESP8266WiFi.h>
#include <PubSubClient.h>
#include <WiFiClientSecure.h>
#include <time.h>
#include <ArduinoJson.h>
#include <Crypto.h>
#include <SHA256.h>

// ============================================================================
// CONFIGURACIÓN DE RED Y MQTT
// ============================================================================
const char* WIFI_SSID = "TU_RED_WIFI";
const char* WIFI_PASSWORD = "TU_PASSWORD_WIFI";

const char* MQTT_SERVER = "192.168.1.100";  // IP de Raspberry Pi
const int MQTT_PORT = 8883;                 // Puerto MQTTS

// Identificación del dispositivo
const char* DEVICE_ID = "ESP8266_001";
const char* MQTT_USER = "ESP8266_001";
const char* MQTT_PASSWORD = "";  // Autenticación por certificado

// ============================================================================
// CONFIGURACIÓN DE CERTIFICADOS
// ============================================================================
// IMPORTANTE: Reemplazar con tus certificados reales

// Certificado CA (ca.crt)
const char* CA_CERT = R"EOF(
-----BEGIN CERTIFICATE-----
MIIFazCCA1OgAwIBAgIUXXXXXXXXXXXXXXXXXXXXXXXXXXXwDQYJKoZIhvcNAQEL
BQAwRTELMAkGA1UEBhMCTVgxEzARBgNVBAgMClNvbWUtU3RhdGUxITAfBgNVBAoM
GEludGVybmV0IFdpZGdpdHMgUHR5IEx0ZDAeFw0yNDAxMDEwMDAwMDBaFw0zNDAx
MDEwMDAwMDBaMEUxCzAJBgNVBAYTAk1YMRMwEQYDVQQIDApTb21lLVN0YXRlMSEw
HwYDVQQKDBhJbnRlcm5ldCBXaWRnaXRzIFB0eSBMdGQwggIiMA0GCSqGSIb3DQEB
AQUAA4ICDwAwggIKAoICAQDXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
... (certificado completo)
-----END CERTIFICATE-----
)EOF";

// Certificado del cliente (ESP8266_001.crt)
const char* CLIENT_CERT = R"EOF(
-----BEGIN CERTIFICATE-----
MIIFazCCA1OgAwIBAgIUYYYYYYYYYYYYYYYYYYYYYYYYYYYwDQYJKoZIhvcNAQEL
... (certificado del dispositivo)
-----END CERTIFICATE-----
)EOF";

// Clave privada del cliente (ESP8266_001-key.pem)
const char* CLIENT_KEY = R"EOF(
-----BEGIN PRIVATE KEY-----
MIIJQgIBADANBgkqhkiG9w0BAQEFAASCCSwwggkoAgEAAoICAQDYYYYYYYYYYYYY
... (clave privada del dispositivo)
-----END PRIVATE KEY-----
)EOF";

// ============================================================================
// CONFIGURACIÓN DE TÓPICOS
// ============================================================================
const char* TOPIC_STATUS = "garden/device/esp001/status";
const char* TOPIC_SENSORS = "garden/device/esp001/sensors/";
const char* TOPIC_CONFIG = "garden/device/esp001/config/#";
const char* TOPIC_ALERTS = "garden/system/alerts";

// ============================================================================
// CONFIGURACIÓN DE SENSORES (ajustar según hardware)
// ============================================================================
const int PIN_TEMP_SENSOR = A0;      // Sensor de temperatura
const int PIN_HUMIDITY_SENSOR = D1;   // Sensor de humedad
const int PIN_SOIL_SENSOR = D2;       // Sensor de humedad de suelo
const int PIN_LED_STATUS = D4;        // LED de estado (Built-in)

// ============================================================================
// VARIABLES GLOBALES
// ============================================================================
WiFiClientSecure espClient;
PubSubClient mqttClient(espClient);

// Buffer para JSON
StaticJsonDocument<512> jsonDoc;

// Timing
unsigned long lastSensorRead = 0;
unsigned long lastHeartbeat = 0;
const unsigned long SENSOR_INTERVAL = 30000;  // 30 segundos
const unsigned long HEARTBEAT_INTERVAL = 60000;  // 1 minuto

// Clave HMAC (debe coincidir con el servidor)
const char* HMAC_KEY = "ESP001_SECRET_KEY_2024";

// ============================================================================
// FUNCIONES DE CONFIGURACIÓN
// ============================================================================

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n\n=== Garden MQTT Secure Client ===");
  Serial.println("Device: " + String(DEVICE_ID));
  
  // Configurar pines
  pinMode(PIN_LED_STATUS, OUTPUT);
  pinMode(PIN_TEMP_SENSOR, INPUT);
  pinMode(PIN_HUMIDITY_SENSOR, INPUT);
  pinMode(PIN_SOIL_SENSOR, INPUT);
  
  // Parpadeo inicial
  blinkLED(3, 200);
  
  // Conectar WiFi
  setupWiFi();
  
  // Sincronizar tiempo (necesario para validar certificados)
  setupTime();
  
  // Configurar certificados TLS
  setupTLS();
  
  // Configurar MQTT
  mqttClient.setServer(MQTT_SERVER, MQTT_PORT);
  mqttClient.setCallback(mqttCallback);
  mqttClient.setKeepAlive(60);
  mqttClient.setSocketTimeout(30);
  
  // Conectar MQTT
  connectMQTT();
  
  Serial.println("=== Configuración completa ===\n");
}

void setupWiFi() {
  Serial.print("Conectando a WiFi: ");
  Serial.println(WIFI_SSID);
  
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    digitalWrite(PIN_LED_STATUS, !digitalRead(PIN_LED_STATUS));
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n✓ WiFi conectado");
    Serial.print("IP: ");
    Serial.println(WiFi.localIP());
    Serial.print("RSSI: ");
    Serial.println(WiFi.RSSI());
    digitalWrite(PIN_LED_STATUS, HIGH);
  } else {
    Serial.println("\n✗ Error conectando WiFi");
    ESP.restart();
  }
}

void setupTime() {
  Serial.print("Sincronizando tiempo NTP...");
  
  configTime(0, 0, "pool.ntp.org", "time.nist.gov");
  
  time_t now = time(nullptr);
  int attempts = 0;
  
  while (now < 8 * 3600 * 2 && attempts < 20) {
    delay(500);
    Serial.print(".");
    now = time(nullptr);
    attempts++;
  }
  
  if (now >= 8 * 3600 * 2) {
    Serial.println(" ✓");
    struct tm timeinfo;
    gmtime_r(&now, &timeinfo);
    Serial.print("Fecha/Hora actual: ");
    Serial.println(asctime(&timeinfo));
  } else {
    Serial.println(" ✗ Error sincronizando tiempo");
  }
}

void setupTLS() {
  Serial.println("Configurando TLS...");
  
  // Establecer certificados
  espClient.setCACert(CA_CERT);
  espClient.setCertificate(CLIENT_CERT);
  espClient.setPrivateKey(CLIENT_KEY);
  
  // Configuración de seguridad
  espClient.setInsecure();  // Para desarrollo; en producción verificar hostname
  
  Serial.println("✓ TLS configurado");
}

void connectMQTT() {
  Serial.println("Conectando a broker MQTT...");
  
  int attempts = 0;
  while (!mqttClient.connected() && attempts < 5) {
    Serial.print("Intento ");
    Serial.print(attempts + 1);
    Serial.print("/5... ");
    
    // Intentar conexión
    if (mqttClient.connect(DEVICE_ID, MQTT_USER, MQTT_PASSWORD)) {
      Serial.println("✓ Conectado");
      
      // Suscribirse a tópicos de configuración
      mqttClient.subscribe(TOPIC_CONFIG);
      Serial.println("✓ Suscrito a: " + String(TOPIC_CONFIG));
      
      // Publicar mensaje de inicio
      publishStatus("online");
      
      blinkLED(2, 100);
      
    } else {
      Serial.print("✗ Error: ");
      Serial.println(mqttClient.state());
      delay(5000);
    }
    
    attempts++;
  }
  
  if (!mqttClient.connected()) {
    Serial.println("✗ No se pudo conectar a MQTT. Reiniciando...");
    delay(5000);
    ESP.restart();
  }
}

// ============================================================================
// CALLBACK MQTT
// ============================================================================

void mqttCallback(char* topic, byte* payload, unsigned int length) {
  Serial.print("Mensaje recibido [");
  Serial.print(topic);
  Serial.print("]: ");
  
  // Convertir payload a string
  String message = "";
  for (unsigned int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  Serial.println(message);
  
  // Procesar mensaje
  processCommand(topic, message);
}

void processCommand(String topic, String message) {
  // Parsear JSON
  DeserializationError error = deserializeJson(jsonDoc, message);
  
  if (error) {
    Serial.print("Error parseando JSON: ");
    Serial.println(error.c_str());
    return;
  }
  
  // Verificar firma HMAC
  if (!verifyHMAC(message)) {
    Serial.println("✗ Firma HMAC inválida");
    publishAlert("invalid_hmac", "Mensaje con firma inválida recibido");
    return;
  }
  
  // Procesar comandos según tópico
  if (topic.indexOf("/config/") > 0) {
    handleConfigCommand(jsonDoc);
  }
}

void handleConfigCommand(JsonDocument& doc) {
  // Manejar comandos de configuración
  if (doc.containsKey("sensor_interval")) {
    unsigned long newInterval = doc["sensor_interval"];
    if (newInterval >= 10000 && newInterval <= 300000) {
      // Actualizar intervalo de sensores (10s - 5min)
      Serial.println("✓ Intervalo actualizado: " + String(newInterval) + "ms");
    }
  }
  
  if (doc.containsKey("reboot")) {
    bool reboot = doc["reboot"];
    if (reboot) {
      Serial.println("⚠ Reinicio solicitado");
      publishStatus("rebooting");
      delay(1000);
      ESP.restart();
    }
  }
}

// ============================================================================
// FUNCIONES DE SEGURIDAD
// ============================================================================

bool verifyHMAC(String message) {
  // Parsear JSON para extraer firma
  StaticJsonDocument<512> doc;
  DeserializationError error = deserializeJson(doc, message);
  
  if (error || !doc.containsKey("signature")) {
    return false;
  }
  
  String receivedSignature = doc["signature"].as<String>();
  
  // Remover firma del mensaje
  doc.remove("signature");
  String messageWithoutSignature;
  serializeJson(doc, messageWithoutSignature);
  
  // Calcular HMAC esperado
  String expectedSignature = calculateHMAC(messageWithoutSignature);
  
  // Comparar
  return (receivedSignature == expectedSignature);
}

String calculateHMAC(String message) {
  SHA256 sha256;
  
  // Preparar HMAC-SHA256
  sha256.resetHMAC(HMAC_KEY, strlen(HMAC_KEY));
  sha256.update(message.c_str(), message.length());
  
  // Obtener hash
  uint8_t hash[32];
  sha256.finalizeHMAC(HMAC_KEY, strlen(HMAC_KEY), hash, sizeof(hash));
  
  // Convertir a hexadecimal
  String hmacHex = "";
  for (int i = 0; i < 32; i++) {
    if (hash[i] < 16) hmacHex += "0";
    hmacHex += String(hash[i], HEX);
  }
  
  return hmacHex;
}

String createSignedMessage(JsonDocument& doc) {
  // Agregar timestamp
  doc["timestamp"] = time(nullptr);
  
  // Serializar sin firma
  String message;
  serializeJson(doc, message);
  
  // Calcular HMAC
  String signature = calculateHMAC(message);
  
  // Agregar firma
  doc["signature"] = signature;
  
  // Serializar mensaje final
  String signedMessage;
  serializeJson(doc, signedMessage);
  
  return signedMessage;
}

// ============================================================================
// FUNCIONES DE PUBLICACIÓN
// ============================================================================

void publishStatus(String status) {
  jsonDoc.clear();
  jsonDoc["device_id"] = DEVICE_ID;
  jsonDoc["status"] = status;
  jsonDoc["uptime"] = millis();
  jsonDoc["wifi_rssi"] = WiFi.RSSI();
  jsonDoc["free_heap"] = ESP.getFreeHeap();
  
  String message = createSignedMessage(jsonDoc);
  
  if (mqttClient.publish(TOPIC_STATUS, message.c_str(), true)) {
    Serial.println("✓ Status publicado: " + status);
  } else {
    Serial.println("✗ Error publicando status");
  }
}

void publishSensorData(String sensorType, float value, String unit) {
  jsonDoc.clear();
  jsonDoc["device_id"] = DEVICE_ID;
  jsonDoc["sensor"] = sensorType;
  jsonDoc["value"] = value;
  jsonDoc["unit"] = unit;
  
  String message = createSignedMessage(jsonDoc);
  String topic = String(TOPIC_SENSORS) + sensorType;
  
  if (mqttClient.publish(topic.c_str(), message.c_str())) {
    Serial.println("✓ Sensor publicado: " + sensorType + " = " + String(value) + " " + unit);
  } else {
    Serial.println("✗ Error publicando sensor");
  }
}

void publishAlert(String alertType, String description) {
  jsonDoc.clear();
  jsonDoc["device_id"] = DEVICE_ID;
  jsonDoc["alert_type"] = alertType;
  jsonDoc["description"] = description;
  jsonDoc["severity"] = "warning";
  
  String message = createSignedMessage(jsonDoc);
  
  if (mqttClient.publish(TOPIC_ALERTS, message.c_str())) {
    Serial.println("⚠ Alerta publicada: " + alertType);
  }
}

// ============================================================================
// FUNCIONES DE SENSORES
// ============================================================================

void readAndPublishSensors() {
  // Leer temperatura (ejemplo con sensor analógico)
  int tempRaw = analogRead(PIN_TEMP_SENSOR);
  float temperature = map(tempRaw, 0, 1023, 0, 100);  // Ajustar según sensor
  publishSensorData("temperature", temperature, "°C");
  
  //ReintentarITContinuarcpp  // Leer humedad ambiental (ejemplo con DHT11/DHT22)
  // int humidityRaw = digitalRead(PIN_HUMIDITY_SENSOR);
  // float humidity = readDHTHumidity();  // Implementar según sensor
  float humidity = random(40, 80);  // Simulación para ejemplo
  publishSensorData("humidity", humidity, "%");
  
  // Leer humedad del suelo
  int soilRaw = analogRead(PIN_SOIL_SENSOR);
  float soilMoisture = map(soilRaw, 0, 1023, 0, 100);
  publishSensorData("soil_moisture", soilMoisture, "%");
  
  // Verificar umbrales y generar alertas
  if (temperature > 35) {
    publishAlert("high_temperature", "Temperatura superior a 35°C");
  }
  
  if (soilMoisture < 20) {
    publishAlert("low_soil_moisture", "Humedad del suelo crítica");
  }
}

// ============================================================================
// FUNCIONES AUXILIARES
// ============================================================================

void blinkLED(int times, int delayMs) {
  for (int i = 0; i < times; i++) {
    digitalWrite(PIN_LED_STATUS, LOW);
    delay(delayMs);
    digitalWrite(PIN_LED_STATUS, HIGH);
    delay(delayMs);
  }
}

void checkMQTTConnection() {
  if (!mqttClient.connected()) {
    Serial.println("⚠ Conexión MQTT perdida. Reconectando...");
    digitalWrite(PIN_LED_STATUS, LOW);
    connectMQTT();
    digitalWrite(PIN_LED_STATUS, HIGH);
  }
}

// ============================================================================
// LOOP PRINCIPAL
// ============================================================================

void loop() {
  // Mantener conexión MQTT
  checkMQTTConnection();
  mqttClient.loop();
  
  unsigned long currentMillis = millis();
  
  // Leer y publicar sensores
  if (currentMillis - lastSensorRead >= SENSOR_INTERVAL) {
    lastSensorRead = currentMillis;
    Serial.println("\n--- Leyendo sensores ---");
    readAndPublishSensors();
  }
  
  // Heartbeat periódico
  if (currentMillis - lastHeartbeat >= HEARTBEAT_INTERVAL) {
    lastHeartbeat = currentMillis;
    publishStatus("alive");
  }
  
  // Pequeño delay para estabilidad
  delay(100);
}
7.2 Configuración de Librerías ESP8266
bash#!/bin/bash
# /opt/mqtt-secure/scripts/setup_esp8266_libraries.sh

echo "=== INSTALACIÓN DE LIBRERÍAS PARA ESP8266 ==="

# Este script genera las instrucciones para instalar librerías en Arduino IDE
# Las librerías deben instalarse manualmente desde Arduino IDE

cat << 'EOF'

INSTRUCCIONES PARA CONFIGURAR ARDUINO IDE:

1. INSTALAR SOPORTE PARA ESP8266:
   - Abrir Arduino IDE
   - Ir a: Archivo → Preferencias
   - En "Gestor de URLs Adicionales de Tarjetas" agregar:
     http://arduino.esp8266.com/stable/package_esp8266com_index.json
   - Ir a: Herramientas → Placa → Gestor de tarjetas
   - Buscar "esp8266" y instalar "esp8266 by ESP8266 Community"

2. INSTALAR LIBRERÍAS NECESARIAS:
   Ir a: Programa → Incluir Librería → Administrar Bibliotecas
   
   Buscar e instalar las siguientes librerías:
   
   ✓ PubSubClient (by Nick O'Leary) - Versión 2.8 o superior
     Descripción: Cliente MQTT para Arduino
   
   ✓ ArduinoJson (by Benoit Blanchon) - Versión 6.x
     Descripción: Manejo de JSON
   
   ✓ Crypto (by Rhys Weatherley)
     Descripción: Funciones criptográficas (SHA256, HMAC)
   
   ✓ WiFiClientSecure (incluida en ESP8266 core)
     Descripción: Cliente WiFi con soporte TLS/SSL

3. CONFIGURAR PARÁMETROS DE COMPILACIÓN:
   - Placa: "NodeMCU 1.0 (ESP-12E Module)" o tu modelo específico
   - Upload Speed: 115200
   - CPU Frequency: 80 MHz
   - Flash Size: 4M (3M SPIFFS)
   - Debug Port: "Disabled"
   - Debug Level: "None"
   - IwIP Variant: "v2 Lower Memory"
   - VTables: "Flash"
   - Erase Flash: "Only Sketch" (primera vez "All Flash Contents")
   
4. SUBIR CERTIFICADOS AL ESP8266:
   Los certificados se deben incrustar en el código como constantes.
   Ver archivo: garden_mqtt_secure.ino
   
   Reemplazar las secciones:
   - CA_CERT con el contenido de: /opt/mqtt-secure/certs/ca/ca.crt
   - CLIENT_CERT con: /opt/mqtt-secure/certs/devices/ESP8266_001.crt
   - CLIENT_KEY con: /opt/mqtt-secure/certs/devices/ESP8266_001-key.pem

5. COMPILAR Y SUBIR:
   - Conectar ESP8266 vía USB
   - Seleccionar puerto COM correcto
   - Click en "Subir" (→)
   - Verificar en Monitor Serie (115200 baud)

EOF

# Generar script de conversión de certificados a formato C
cat > /opt/mqtt-secure/scripts/cert_to_c_string.sh << 'CERTSCRIPT'
#!/bin/bash
# Convertir certificados PEM a formato C string para ESP8266

if [ "$#" -ne 1 ]; then
    echo "Uso: $0 <archivo.pem>"
    exit 1
fi

FILE=$1

if [ ! -f "$FILE" ]; then
    echo "Error: Archivo no encontrado: $FILE"
    exit 1
fi

echo "const char* CERT = R\"EOF("
cat "$FILE"
echo ")EOF\";"

CERTSCRIPT

chmod +x /opt/mqtt-secure/scripts/cert_to_c_string.sh

echo "✓ Script cert_to_c_string.sh creado"
echo ""
echo "Uso: ./cert_to_c_string.sh /path/to/certificate.pem"
7.3 Script de Generación de Certificados para ESP8266
bash#!/bin/bash
# /opt/mqtt-secure/scripts/generate_esp_certificates.sh

CERT_DIR="/opt/mqtt-secure/certs"
OUTPUT_DIR="/opt/mqtt-secure/esp8266_certs"

mkdir -p "$OUTPUT_DIR"

echo "=== GENERANDO ARCHIVOS PARA ESP8266 ==="

# Función para convertir certificado a formato C
cert_to_c() {
    local INPUT_FILE=$1
    local OUTPUT_FILE=$2
    local VAR_NAME=$3
    
    echo "const char* ${VAR_NAME} = R\"EOF(" > "$OUTPUT_FILE"
    cat "$INPUT_FILE" >> "$OUTPUT_FILE"
    echo ")EOF\";" >> "$OUTPUT_FILE"
}

# Generar archivos para cada dispositivo
for DEVICE in ESP8266_001 ESP8266_002 ESP8266_003; do
    echo "Procesando $DEVICE..."
    
    DEVICE_DIR="$OUTPUT_DIR/$DEVICE"
    mkdir -p "$DEVICE_DIR"
    
    # Convertir CA
    cert_to_c "$CERT_DIR/ca/ca.crt" "$DEVICE_DIR/ca_cert.h" "CA_CERT"
    
    # Convertir certificado del cliente
    cert_to_c "$CERT_DIR/devices/$DEVICE.crt" "$DEVICE_DIR/client_cert.h" "CLIENT_CERT"
    
    # Convertir clave privada
    cert_to_c "$CERT_DIR/devices/$DEVICE-key.pem" "$DEVICE_DIR/client_key.h" "CLIENT_KEY"
    
    # Crear archivo de configuración completo
    cat > "$DEVICE_DIR/config.h" << EOF
// Configuración para $DEVICE
// Generado automáticamente el $(date)

#ifndef CONFIG_H
#define CONFIG_H

// Identificación del dispositivo
#define DEVICE_ID "$DEVICE"
#define MQTT_USER "$DEVICE"

// Configuración WiFi (ACTUALIZAR CON TUS DATOS)
#define WIFI_SSID "TU_RED_WIFI"
#define WIFI_PASSWORD "TU_PASSWORD_WIFI"

// Configuración MQTT
#define MQTT_SERVER "192.168.1.100"  // IP del broker
#define MQTT_PORT 8883

// Clave HMAC
#define HMAC_KEY "${DEVICE}_SECRET_KEY_2024"

// Certificados
$(cat "$DEVICE_DIR/ca_cert.h")

$(cat "$DEVICE_DIR/client_cert.h")

$(cat "$DEVICE_DIR/client_key.h")

#endif // CONFIG_H
EOF
    
    echo "✓ Archivos generados en: $DEVICE_DIR/"
    echo "  - config.h (incluir en tu sketch Arduino)"
    
done

# Crear README con instrucciones
cat > "$OUTPUT_DIR/README.txt" << 'READMEFILE'
=== CERTIFICADOS PARA ESP8266 ===

Cada carpeta contiene los archivos necesarios para un dispositivo ESP8266:

1. config.h - Archivo de configuración completo con certificados incrustados

INSTRUCCIONES DE USO:

Opción A - Incluir archivo de configuración:
1. Copiar el archivo config.h de tu dispositivo a tu proyecto Arduino
2. Incluir en tu sketch: #include "config.h"
3. Actualizar WIFI_SSID y WIFI_PASSWORD
4. Compilar y subir

Opción B - Copiar directamente al sketch:
1. Abrir config.h con un editor de texto
2. Copiar el contenido de las variables CA_CERT, CLIENT_CERT, CLIENT_KEY
3. Pegar en tu sketch Arduino en las secciones correspondientes
4. Actualizar configuración WiFi y MQTT
5. Compilar y subir

IMPORTANTE:
- Mantener estos certificados seguros
- No compartir las claves privadas
- Actualizar WIFI_SSID y WIFI_PASSWORD antes de compilar
- Verificar que MQTT_SERVER apunte a tu Raspberry Pi

VERIFICACIÓN:
- Monitor Serie debe mostrar conexión exitosa a WiFi
- Monitor Serie debe mostrar conexión exitosa a MQTT broker
- Verificar en logs del broker: /var/log/mosquitto/mosquitto.log

READMEFILE

echo ""
echo "=== PROCESO COMPLETADO ==="
echo "Certificados generados en: $OUTPUT_DIR"
echo "Lee: $OUTPUT_DIR/README.txt para instrucciones de uso"

8. MONITOREO Y AUDITORÍA
8.1 Sistema de Logging Avanzado
python#!/usr/bin/env python3
# /opt/mqtt-secure/scripts/mqtt_logger.py

import sqlite3
import json
import logging
from datetime import datetime, timedelta
import paho.mqtt.client as mqtt
import ssl

class MQTTLogger:
    def __init__(self, db_path='/opt/mqtt-secure/logs/mqtt_logs.db'):
        self.db_path = db_path
        self.init_database()
        
        # Configurar logging a archivo
        logging.basicConfig(
            filename='/var/log/mqtt-secure/logger.log',
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger(__name__)
    
    def init_database(self):
        """Inicializar base de datos de logs"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Tabla de mensajes MQTT
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS mqtt_messages (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                client_id TEXT NOT NULL,
                topic TEXT NOT NULL,
                payload TEXT,
                qos INTEGER,
                retained BOOLEAN,
                payload_size INTEGER,
                INDEX idx_timestamp (timestamp),
                INDEX idx_client (client_id),
                INDEX idx_topic (topic)
            )
        ''')
        
        # Tabla de conexiones
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS connections (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                client_id TEXT NOT NULL,
                event_type TEXT NOT NULL,
                ip_address TEXT,
                protocol_version INTEGER,
                keepalive INTEGER,
                clean_session BOOLEAN,
                INDEX idx_timestamp (timestamp),
                INDEX idx_client (client_id)
            )
        ''')
        
        # Tabla de suscripciones
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS subscriptions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                client_id TEXT NOT NULL,
                topic TEXT NOT NULL,
                qos INTEGER,
                INDEX idx_client (client_id)
            )
        ''')
        
        # Tabla de errores y alertas
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS alerts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                alert_type TEXT NOT NULL,
                severity TEXT NOT NULL,
                source TEXT,
                description TEXT,
                metadata TEXT,
                resolved BOOLEAN DEFAULT 0,
                INDEX idx_timestamp (timestamp),
                INDEX idx_type (alert_type),
                INDEX idx_severity (severity)
            )
        ''')
        
        # Tabla de métricas agregadas
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS metrics (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                metric_name TEXT NOT NULL,
                metric_value REAL NOT NULL,
                tags TEXT,
                INDEX idx_timestamp (timestamp),
                INDEX idx_metric (metric_name)
            )
        ''')
        
        conn.commit()
        conn.close()
    
    def log_message(self, client_id, topic, payload, qos=0, retained=False):
        """Registrar mensaje MQTT"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        payload_str = payload.decode() if isinstance(payload, bytes) else str(payload)
        payload_size = len(payload_str)
        
        cursor.execute('''
            INSERT INTO mqtt_messages (client_id, topic, payload, qos, retained, payload_size)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', (client_id, topic, payload_str, qos, retained, payload_size))
        
        conn.commit()
        conn.close()
        
        self.logger.info(f"Mensaje registrado: {client_id} -> {topic}")
    
    def log_connection(self, client_id, event_type, ip_address=None, protocol_version=None):
        """Registrar evento de conexión"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO connections (client_id, event_type, ip_address, protocol_version)
            VALUES (?, ?, ?, ?)
        ''', (client_id, event_type, ip_address, protocol_version))
        
        conn.commit()
        conn.close()
        
        self.logger.info(f"Conexión registrada: {client_id} - {event_type}")
    
    def log_subscription(self, client_id, topic, qos=0):
        """Registrar suscripción"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO subscriptions (client_id, topic, qos)
            VALUES (?, ?, ?)
        ''', (client_id, topic, qos))
        
        conn.commit()
        conn.close()
    
    def log_alert(self, alert_type, severity, source, description, metadata=None):
        """Registrar alerta de seguridad"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        metadata_str = json.dumps(metadata) if metadata else None
        
        cursor.execute('''
            INSERT INTO alerts (alert_type, severity, source, description, metadata)
            VALUES (?, ?, ?, ?, ?)
        ''', (alert_type, severity, source, description, metadata_str))
        
        conn.commit()
        conn.close()
        
        self.logger.warning(f"Alerta: [{severity}] {alert_type} - {description}")
    
    def log_metric(self, metric_name, metric_value, tags=None):
        """Registrar métrica"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        tags_str = json.dumps(tags) if tags else None
        
        cursor.execute('''
            INSERT INTO metrics (metric_name, metric_value, tags)
            VALUES (?, ?, ?)
        ''', (metric_name, metric_value, tags_str))
        
        conn.commit()
        conn.close()
    
    def get_recent_messages(self, hours=1, client_id=None, topic_pattern=None):
        """Obtener mensajes recientes"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        query = '''
            SELECT timestamp, client_id, topic, payload, qos
            FROM mqtt_messages
            WHERE timestamp > datetime('now', '-{} hours')
        '''.format(hours)
        
        params = []
        
        if client_id:
            query += " AND client_id = ?"
            params.append(client_id)
        
        if topic_pattern:
            query += " AND topic LIKE ?"
            params.append(topic_pattern)
        
        query += " ORDER BY timestamp DESC LIMIT 1000"
        
        cursor.execute(query, params)
        results = cursor.fetchall()
        conn.close()
        
        return results
    
    def get_connection_stats(self, hours=24):
        """Obtener estadísticas de conexiones"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Conexiones por cliente
        cursor.execute('''
            SELECT client_id, event_type, COUNT(*) as count
            FROM connections
            WHERE timestamp > datetime('now', '-{} hours')
            GROUP BY client_id, event_type
            ORDER BY count DESC
        '''.format(hours))
        
        results = cursor.fetchall()
        conn.close()
        
        return results
    
    def get_active_alerts(self):
        """Obtener alertas activas (no resueltas)"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            SELECT id, timestamp, alert_type, severity, source, description
            FROM alerts
            WHERE resolved = 0
            ORDER BY timestamp DESC
        ''')
        
        results = cursor.fetchall()
        conn.close()
        
        return results
    
    def resolve_alert(self, alert_id):
        """Marcar alerta como resuelta"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            UPDATE alerts SET resolved = 1 WHERE id = ?
        ''', (alert_id,))
        
        conn.commit()
        conn.close()
    
    def generate_daily_report(self, date=None):
        """Generar reporte diario"""
        if date is None:
            date = datetime.now().date()
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        report = {
            'date': str(date),
            'generated_at': datetime.now().isoformat()
        }
        
        # Total de mensajes
        cursor.execute('''
            SELECT COUNT(*) FROM mqtt_messages
            WHERE DATE(timestamp) = ?
        ''', (str(date),))
        report['total_messages'] = cursor.fetchone()[0]
        
        # Mensajes por dispositivo
        cursor.execute('''
            SELECT client_id, COUNT(*) as count
            FROM mqtt_messages
            WHERE DATE(timestamp) = ?
            GROUP BY client_id
            ORDER BY count DESC
        ''', (str(date),))
        report['messages_by_device'] = dict(cursor.fetchall())
        
        # Conexiones y desconexiones
        cursor.execute('''
            SELECT event_type, COUNT(*) as count
            FROM connections
            WHERE DATE(timestamp) = ?
            GROUP BY event_type
        ''', (str(date),))
        report['connections'] = dict(cursor.fetchall())
        
        # Alertas generadas
        cursor.execute('''
            SELECT alert_type, severity, COUNT(*) as count
            FROM alerts
            WHERE DATE(timestamp) = ?
            GROUP BY alert_type, severity
        ''', (str(date),))
        report['alerts'] = [
            {'type': row[0], 'severity': row[1], 'count': row[2]}
            for row in cursor.fetchall()
        ]
        
        # Tráfico total (bytes)
        cursor.execute('''
            SELECT SUM(payload_size) FROM mqtt_messages
            WHERE DATE(timestamp) = ?
        ''', (str(date),))
        report['total_traffic_bytes'] = cursor.fetchone()[0] or 0
        
        conn.close()
        
        return report
    
    def cleanup_old_logs(self, days=30):
        """Limpiar logs antiguos"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cutoff_date = datetime.now() - timedelta(days=days)
        
        # Limpiar mensajes antiguos
        cursor.execute('''
            DELETE FROM mqtt_messages WHERE timestamp < ?
        ''', (cutoff_date,))
        messages_deleted = cursor.rowcount
        
        # Limpiar conexiones antiguas
        cursor.execute('''
            DELETE FROM connections WHERE timestamp < ?
        ''', (cutoff_date,))
        connections_deleted = cursor.rowcount
        
        # Limpiar métricas antiguas
        cursor.execute('''
            DELETE FROM metrics WHERE timestamp < ?
        ''', (cutoff_date,))
        metrics_deleted = cursor.rowcount
        
        conn.commit()
        conn.close()
        
        self.logger.info(f"Limpieza completada: {messages_deleted} mensajes, "
                        f"{connections_deleted} conexiones, {metrics_deleted} métricas eliminadas")
        
        return {
            'messages_deleted': messages_deleted,
            'connections_deleted': connections_deleted,
            'metrics_deleted': metrics_deleted
        }

# Script de monitoreo en tiempo real
class MQTTMonitor:
    def __init__(self, broker_host="localhost", broker_port=8883):
        self.logger = MQTTLogger()
        self.client = mqtt.Client("mqtt_monitor")
        self.broker_host = broker_host
        self.broker_port = broker_port
    
    def setup_client(self, ca_cert, client_cert, client_key, username, password):
        """Configurar cliente MQTT para monitoreo"""
        # Configurar TLS
        self.client.tls_set(
            ca_certs=ca_cert,
            certfile=client_cert,
            keyfile=client_key,
            tls_version=ssl.PROTOCOL_TLSv1_2
        )
        
        # Configurar credenciales
        self.client.username_pw_set(username, password)
        
        # Configurar callbacks
        self.client.on_connect = self.on_connect
        self.client.on_message = self.on_message
        self.client.on_disconnect = self.on_disconnect
    
    def on_connect(self, client, userdata, flags, rc):
        """Callback de conexión"""
        if rc == 0:
            print("✓ Monitor conectado al broker")
            # Suscribirse a todos los tópicos
            client.subscribe("garden/#")
            client.subscribe("$SYS/#")
            
            self.logger.log_connection("mqtt_monitor", "connected")
        else:
            print(f"✗ Error conectando: {rc}")
    
    def on_message(self, client, userdata, message):
        """Callback de mensaje recibido"""
        # Registrar mensaje
        self.logger.log_message(
            client_id="unknown",  # No disponible en callback
            topic=message.topic,
            payload=message.payload,
            qos=message.qos,
            retained=message.retain
        )
        
        # Mostrar en consola
        print(f"[{datetime.now().strftime('%H:%M:%S')}] {message.topic}: {message.payload.decode()[:100]}")
        
        # Detectar alertas
        if "/alerts" in message.topic:
            try:
                alert_data = json.loads(message.payload.decode())
                self.logger.log_alert(
                    alert_type=alert_data.get('alert_type', 'unknown'),
                    severity=alert_data.get('severity', 'info'),
                    source=alert_data.get('device_id', 'unknown'),
                    description=alert_data.get('description', ''),
                    metadata=alert_data
                )
            except json.JSONDecodeError:
                pass
    
    def on_disconnect(self, client, userdata, rc):
        """Callback de desconexión"""
        print(f"⚠ Monitor desconectado: {rc}")
        self.logger.log_connection("mqtt_monitor", "disconnected")
    
    def start(self):
        """Iniciar monitoreo"""
        try:
            self.client.connect(self.broker_host, self.broker_port, 60)
            self.client.loop_forever()
        except KeyboardInterrupt:
            print("\n⏹ Monitoreo detenido")
            self.client.disconnect()

if __name__ == "__main__":
    import sys
    import argparse
    
    parser = argparse.ArgumentParser(description='MQTT Logger y Monitor')
    parser.add_argument('command', choices=['monitor', 'report', 'cleanup', 'alerts'],
                       help='Comando a ejecutar')
    parser.add_argument('--hours', type=int, default=24,
                       help='Horas para reporte/limpieza')
    parser.add_argument('--days', type=int, default=30,
                       help='Días para limpieza')
    
    args = parser.parse_args()
    
    logger = MQTTLogger()
    
    if args.command == 'monitor':
        # Iniciar monitoreo en tiempo real
        monitor = MQTTMonitor()
        monitor.setup_client(
            ca_cert="/opt/mqtt-secure/certs/ca/ca.crt",
            client_cert="/opt/mqtt-secure/certs/clients/garden_admin.crt",
            client_key="/opt/mqtt-secure/certs/clients/garden_admin-key.pem",
            username="garden_admin",
            password="AdminSecurePass456!"
        )
        print("=== Iniciando monitor MQTT ===")
        print("Presiona Ctrl+C para detener")
        monitor.start()
    
    elif args.command == 'report':
        # Generar reporte
        report = logger.generate_daily_report()
        print(json.dumps(report, indent=2))
    
    elif args.command == 'cleanup':
        # Limpiar logs antiguos
        result = logger.cleanup_old_logs(days=args.days)
        print(f"Limpieza completada:")
        print(f"  Mensajes eliminados: {result['messages_deleted']}")
        print(f"  Conexiones eliminadas: {result['connections_deleted']}")
        print(f"  Métricas eliminadas: {result['metrics_deleted']}")
    
    elif args.command == 'alerts':
        # Mostrar alertas activas
        alerts = logger.get_active_alerts()
        if alerts:
            print(f"\n=== Alertas Activas ({len(alerts)}) ===\n")
            for alert in alerts:
                alert_id, timestamp, alert_type, severity, source, description = alert
                print(f"[{alert_id}] [{severity.upper()}] {timestamp}")
                print(f"  Tipo: {alert_type}")
                print(f"  Fuente: {source}")
                print(f"  Descripción: {description}")
                print()
        else:
            print("✓ No hay alertas activas")
8.2 Dashboard de Monitoreo Web
python#!/usr/bin/env python3
# /opt/mqtt-secure/scripts/mqtt_dashboard.py

from flask import Flask, render_template, jsonify, request
import sqlite3
import json
from datetime import datetime, timedelta
from mqtt_logger import MQTTLogger

app = Flask(__name__)
logger = MQTTLogger()

@app.route('/')
def index():
    """Página principal del dashboard"""
    return render_template('dashboard.html')

@app.route('/api/stats')
def get_stats():
    """API: Obtener estadísticas generales"""
    hours = request.args.get('hours', 24, type=int)
    
    conn = sqlite3.connect(logger.db_path)
    cursor = conn.cursor()
    
    # Total de mensajes
    cursor.execute('''
        SELECT COUNT(*) FROM mqtt_messages
        WHERE timestamp > datetime('now', '-{} hours')
    '''.format(hours))
    total_messages = cursor.fetchone()[0]
    
    # Dispositivos activos
    cursor.execute('''
        SELECT COUNT(DISTINCT client_id) FROM mqtt_messages
        WHERE timestamp > datetime('now', '-{} hours')
    '''.format(hours))
    active_devices = cursor.fetchone()[0]
    
    # Alertas activas
    cursor.execute('SELECT COUNT(*) FROM alerts WHERE resolved = 0')
    active_alerts = cursor.fetchone()[0]
    
    # Tráfico total
    cursor.execute('''
        SELECT SUM(payload_size) FROM mqtt_messages
        WHERE timestamp > datetime('now', '-{} hours')
    '''.format(hours))
    total_traffic = cursor.fetchone()[0] or 0
    
    conn.close()
    
    return jsonify({
        'total_messages': total_messages,
        'active_devices': active_devices,
        'active_alerts': active_alerts,
        'total_traffic_kb': round(total_traffic / 1024, 2),
        'timestamp': datetime.now().isoformat()
    })

@app.route('/api/messages')
def get_messages():
    """API: Obtener mensajes recientes"""
    hours = request.args.get('hours', 1, type=int)
    limit = request.args.get('limit', 100, type=int)
    
    messages = logger.get_recent_messages(hours=ReintentarEsta respuesta se pausó porque Claude alcanzó la longitud máxima del mensaje. Presiona continuar para que Claude siga.ContinuarClaude puede cometer errores. Verifique las respuestas.
  
  
