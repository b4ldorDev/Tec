# Manual Completo: Implementación MQTT Ultra Seguro para Huerto Automatizado
## Sistema Profesional de Autenticación y Autorización

---

# ÍNDICE

1. [Introducción y Arquitectura](#1-introducción-y-arquitectura)
2. [Preparación del Entorno](#2-preparación-del-entorno)
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

## 6. AUTORIZACIÓN GRANULAR

### 6.1 Archivo de Control de Acceso (ACL)

```bash
# /etc/mosquitto/acl
# Control de Acceso Granular para Garden MQTT System

# ============================================================================
# CONFIGURACIÓN GLOBAL
# ============================================================================
# Denegar acceso por defecto
# Todo debe ser explícitamente permitido

# ============================================================================
# ADMINISTRADOR DEL SISTEMA
# ============================================================================
user garden_admin
topic readwrite garden/+/+
topic readwrite $SYS/+

# ============================================================================
# DISPOSITIVOS ESP8266
# ============================================================================

# ESP8266 #1 - Sensores
user ESP8266_001
topic read garden/device/esp001/config/+
topic write garden/device/esp001/status
topic write garden/device/esp001/sensors/+
topic write garden/system/alerts
topic write garden/system/health
