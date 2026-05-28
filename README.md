# Proyecto Integrador — Sistemas Operativos
## Diseño, configuración y despliegue de una aplicación en entornos virtualizados y en la nube

---

## Arquitectura de la solución

```
┌─────────────────────────────────────────────────────┐
│  VirtualBox VM / Cloud VM (Ubuntu Server 22.04)     │
│                                                     │
│  ┌─────────────────  Docker Compose  ─────────────┐ │
│  │                                                │ │
│  │  [Frontend]        [Backend]       [Database]  │ │
│  │  nginx:alpine  →  node:20-alpine → postgres:15 │ │
│  │  Puerto :80        Puerto :3000    Puerto :5432 │ │
│  │                                                │ │
│  └────────────────────────────────────────────────┘ │
│                                                     │
│  Red Docker: appnet (bridge)                        │
│  Volumen:    pgdata (persistencia PostgreSQL)       │
└─────────────────────────────────────────────────────┘
         ↑
  Navegador del host (http://IP_VM:80)
```

**Tecnologías usadas:**
- **Frontend:** HTML + CSS + JS vanilla, servido por Nginx
- **Backend:** Node.js 20 con Express, API REST
- **Base de datos:** PostgreSQL 15
- **Orquestación:** Docker Compose
- **OS:** Ubuntu Server 22.04 LTS
- **VM:** VirtualBox

---

## FASE 1 — Instalación y preparación del entorno

### 1.1 Crear la VM en VirtualBox

1. Descargar **Ubuntu Server 22.04 LTS** desde [ubuntu.com/download/server](https://ubuntu.com/download/server)
2. En VirtualBox: Nueva VM
   - Nombre: `ProyectoIntegrador`
   - Tipo: Linux / Ubuntu (64-bit)
   - RAM: **2048 MB mínimo** (recomendado 4096 MB)
   - Disco: **20 GB** (VDI, dinámico)
3. Configurar red: `Configuración → Red → Adaptador 1 → Adaptado de puente` (Bridge)
   - Esto permite acceder desde el navegador del host
4. Iniciar VM y completar la instalación de Ubuntu Server

### 1.2 Configuración inicial post-instalación

```bash
# Verificar que hay red
ip a
ping 8.8.8.8 -c 3

# Actualizar el sistema
sudo apt update && sudo apt upgrade -y

# Verificar información del sistema
whoami
hostname
uname -a

# Instalar herramientas útiles
sudo apt install -y curl wget git net-tools htop
```

Evidencias requeridas: captura de `ip a`, `whoami`, `hostname`

---

## FASE 2 — Administración del sistema

### 2.1 Gestión de usuarios

```bash
# Crear usuario para el proyecto
sudo useradd -m -s /bin/bash piuser
sudo passwd piuser

# Agregar al grupo docker (lo haremos al instalar Docker)
# Por ahora agregar a sudo
sudo usermod -aG sudo piuser

# Verificar usuarios del sistema
cat /etc/passwd | grep -v nologin | grep -v false

# Ver grupos del usuario
groups piuser
```

### 2.2 Gestión de permisos

```bash
# Crear directorio del proyecto
sudo mkdir -p /opt/proyecto-integrador
sudo chown piuser:piuser /opt/proyecto-integrador
sudo chmod 755 /opt/proyecto-integrador

# Verificar permisos
ls -la /opt/
```

### 2.3 Monitoreo de procesos y recursos

```bash
# Ver procesos en tiempo real
top
htop          # más visual (instalar: sudo apt install htop)

# Listar todos los procesos
ps -aux

# Ver uso de memoria
free -m

# Ver uso de disco
df -h

# Ver carga del sistema
uptime
```

---

## FASE 3 — Automatización (Script Bash)

### 3.1 Instalar Docker primero (necesario para el script)

```bash
# Instalacion oficial de Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Agregar usuario actual al grupo docker (para no usar sudo siempre)
sudo usermod -aG docker $USER

# Aplicar cambio de grupo sin reiniciar
newgrp docker

# Verificar instalacion
docker --version
docker-compose --version   # o: docker compose version
```

### 3.2 Copiar el proyecto a la VM

**Opción A — desde la terminal de la VM (recomendado):**
```bash
# Clonar o crear el directorio
cd /opt/proyecto-integrador

# Copiar los archivos del proyecto aquí (ver estructura abajo)
```

**Opción B — desde tu máquina anfitriona via SCP:**
```bash
# Desde tu PC (reemplaza IP_VM con la IP de tu VM)
scp -r ./proyecto-integrador usuario@IP_VM:/opt/
```

### 3.3 Estructura de archivos en la VM

```
/opt/proyecto-integrador/
├── docker-compose.yml
├── .env
├── backend/
│   ├── Dockerfile
│   ├── package.json
│   ├── server.js
│   └── init.sql
├── frontend/
│   ├── Dockerfile
│   ├── nginx.conf
│   └── index.html
├── scripts/
│   └── gestion.sh
├── logs/           ← creado automáticamente por el script
└── backups/        ← creado automáticamente al hacer backup
```

### 3.4 Ejecutar el script de automatización

```bash
cd /opt/proyecto-integrador

# Dar permisos de ejecucion al script
chmod +x scripts/gestion.sh

# Ejecutar en modo interactivo (menu)
bash scripts/gestion.sh

# O ejecutar una accion directamente:
bash scripts/gestion.sh todo        # setup completo
bash scripts/gestion.sh monitorear  # solo monitoreo
bash scripts/gestion.sh backup      # solo backup
bash scripts/gestion.sh logs        # ver logs
```

---

## FASE 4 — Despliegue local (On-Premise)

```bash
cd /opt/proyecto-integrador

# Levantar todos los contenedores
docker-compose up -d

# Ver que esten corriendo
docker ps

# Ver logs de cada contenedor
docker logs pi_backend
docker logs pi_frontend
docker logs pi_db

# Ver uso de recursos de los contenedores
docker stats

# Acceder a la aplicacion desde el navegador del HOST:
# http://IP_VM:80
```

**Para saber la IP de tu VM:**
```bash
ip a | grep "inet " | grep -v 127
```

**Verificar que los puertos responden:**
```bash
curl http://localhost:80
curl http://localhost:3000/api/health
```

---

## FASE 5 — Seguridad básica y puertos

### 5.1 Configurar firewall (UFW)

```bash
# Ver estado del firewall
sudo ufw status

# Habilitar UFW
sudo ufw enable

# Permitir SSH (IMPORTANTE: antes de habilitar para no quedarse sin acceso)
sudo ufw allow 22

# Permitir los puertos de la aplicacion
sudo ufw allow 80
sudo ufw allow 3000

# Ver reglas activas
sudo ufw status verbose
```

### 5.2 Verificar puertos abiertos

```bash
# Ver puertos en escucha
ss -tlnp
# o
netstat -tlnp
```

### 5.3 Variables de entorno

Las variables sensibles están en el archivo `.env`:
```
DB_NAME=taskdb
DB_USER=admin
DB_PASSWORD=secret123
```

**Nunca** subir el `.env` a repositorios públicos. Agregar al `.gitignore`:
```bash
echo ".env" >> .gitignore
```

---

## FASE 6 — Despliegue en Cloud

### Opción A — Railway (más fácil, gratuito)

1. Crear cuenta en [railway.app](https://railway.app)
2. Conectar repositorio GitHub con el proyecto
3. Railway detecta el `docker-compose.yml` automáticamente
4. Configurar las variables de entorno en el panel de Railway
5. La app queda con URL pública

### Opción B — Oracle Cloud (VM en la nube, gratis para siempre)

```bash
# 1. Crear cuenta en cloud.oracle.com (Always Free tier)
# 2. Crear VM Ubuntu 22.04 (Ampere ARM o AMD)
# 3. Descargar la clave SSH (.pem)

# Conectarse por SSH desde tu PC:
chmod 400 mi_clave.pem
ssh -i mi_clave.pem ubuntu@IP_PUBLICA_CLOUD

# 4. Una vez dentro, repetir los pasos de instalacion:
sudo apt update && sudo apt upgrade -y
curl -fsSL https://get.docker.com | bash
sudo usermod -aG docker ubuntu
newgrp docker

# 5. Copiar el proyecto
git clone https://github.com/tu-usuario/proyecto-integrador.git
# o usar scp desde tu PC

# 6. Levantar
cd proyecto-integrador
docker-compose up -d

# 7. Abrir puertos en el panel de Oracle Cloud:
#    Security List → Ingress Rules → agregar puerto 80 y 3000

# 8. Acceder desde internet:
# http://IP_PUBLICA:80
```

### Opción C — Render (alternativa gratuita)

1. Crear cuenta en [render.com](https://render.com)
2. New → Web Service → conectar GitHub
3. Seleccionar `backend/` como directorio
4. Build command: `npm install`
5. Start command: `node server.js`
6. Agregar variables de entorno en el panel
7. Para PostgreSQL: New → PostgreSQL (plan gratuito disponible)

---

## Comandos útiles de Docker

```bash
# Ver contenedores corriendo
docker ps

# Ver TODOS los contenedores (incluyendo detenidos)
docker ps -a

# Ver imagenes descargadas
docker images

# Detener todos los contenedores del proyecto
docker-compose down

# Detener Y borrar volumenes (cuidado: borra datos de BD)
docker-compose down -v

# Reconstruir imagenes y levantar
docker-compose up -d --build

# Ver logs en tiempo real
docker logs -f pi_backend

# Entrar a un contenedor
docker exec -it pi_backend sh
docker exec -it pi_db psql -U admin -d taskdb

# Ver estadisticas de recursos
docker stats --no-stream
```

---

## Verificación final

```bash
# 1. Ver contenedores activos
docker ps

# 2. Verificar API backend
curl http://localhost:3000/api/health

# 3. Verificar que la BD responde
curl http://localhost:3000/api/tasks

# 4. Abrir en navegador del HOST
# http://IP_VM:80

# 5. Ver estado del firewall
sudo ufw status

# 6. Monitorear con el script
bash scripts/gestion.sh monitorear
```

---

## Solución de problemas comunes

| Problema | Causa probable | Solución |
|----------|---------------|----------|
| `docker: command not found` | Docker no instalado | `curl -fsSL https://get.docker.com \| bash` |
| `Permission denied` al usar docker | Usuario no en grupo docker | `sudo usermod -aG docker $USER && newgrp docker` |
| Contenedor backend no inicia | BD no lista | Esperar 15s y `docker-compose restart backend` |
| No se accede desde el navegador | Firewall bloqueando | `sudo ufw allow 80 && sudo ufw allow 3000` |
| Puerto 80 ocupado | Otro servicio en :80 | `sudo lsof -i :80` y detener ese proceso |
| Red Bridge no funciona | VirtualBox modo NAT | Cambiar a **Adaptador puente** en configuración de red |
