#!/bin/bash
# =============================================================================
# Script de Automatizacion — Proyecto Integrador de Sistemas Operativos
# Autor: [Tu nombre]
# Descripcion: Automatiza la gestion, monitoreo y despliegue del proyecto.
# Uso: bash gestion.sh [opcion]
# =============================================================================

# ── Configuracion global ──────────────────────────────────────────────────────
PROYECTO_DIR="$(cd "$(dirname "$0")" && pwd)"    # directorio donde esta el script
LOG_DIR="$PROYECTO_DIR/logs"                      # carpeta para los logs
LOG_FILE="$LOG_DIR/gestion_$(date +%F).log"       # un log por dia
COMPOSE_FILE="$PROYECTO_DIR/docker-compose.yml"

# Colores para la consola
VERDE="\033[0;32m"
ROJO="\033[0;31m"
AMARILLO="\033[1;33m"
AZUL="\033[0;34m"
RESET="\033[0m"
NEGRITA="\033[1m"

# ── Funciones de utilidad ─────────────────────────────────────────────────────

# Crea el directorio de logs si no existe
inicializar_logs() {
    mkdir -p "$LOG_DIR"
}

# Escribe un mensaje en el log con timestamp
log() {
    local nivel="$1"
    local mensaje="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$nivel] $mensaje" >> "$LOG_FILE"
}

# Muestra un mensaje con color en consola Y lo guarda en el log
info()  { echo -e "${AZUL}[INFO]${RESET}  $1"; log "INFO"  "$1"; }
ok()    { echo -e "${VERDE}[ OK ]${RESET}  $1"; log "OK"    "$1"; }
warn()  { echo -e "${AMARILLO}[WARN]${RESET}  $1"; log "WARN"  "$1"; }
error() { echo -e "${ROJO}[ERR ]${RESET}  $1"; log "ERROR" "$1"; }

# Imprime una linea separadora
separador() {
    echo -e "\n${NEGRITA}──────────────────────────────────────────${RESET}"
    echo -e "${NEGRITA}  $1${RESET}"
    echo -e "${NEGRITA}──────────────────────────────────────────${RESET}\n"
}

# Verifica si un comando existe en el sistema
comando_existe() {
    command -v "$1" &>/dev/null
}

# ── 1. Actualizar el sistema ──────────────────────────────────────────────────
actualizar_sistema() {
    separador "1. Actualizacion del sistema"
    info "Actualizando lista de paquetes..."
    log "INFO" "Inicio de actualizacion del sistema"

    if sudo apt-get update -y >> "$LOG_FILE" 2>&1; then
        ok "Lista de paquetes actualizada."
    else
        error "Fallo al actualizar lista de paquetes."
        return 1
    fi

    info "Instalando actualizaciones disponibles..."
    if sudo apt-get upgrade -y >> "$LOG_FILE" 2>&1; then
        ok "Sistema actualizado correctamente."
    else
        warn "Algunas actualizaciones no se aplicaron."
    fi
}

# ── 2. Validar Docker ─────────────────────────────────────────────────────────
validar_docker() {
    separador "2. Validacion de Docker"

    # Verificar instalacion de Docker
    if comando_existe docker; then
        local version
        version=$(docker --version 2>/dev/null)
        ok "Docker instalado: $version"
        log "OK" "Docker presente: $version"
    else
        error "Docker NO esta instalado."
        info  "Ejecuta: curl -fsSL https://get.docker.com | bash"
        return 1
    fi

    # Verificar instalacion de Docker Compose
    if comando_existe docker-compose || docker compose version &>/dev/null; then
        ok "Docker Compose disponible."
    else
        error "Docker Compose NO encontrado."
        return 1
    fi

    # Verificar que el daemon de Docker este corriendo
    if docker info &>/dev/null; then
        ok "Daemon de Docker corriendo."
    else
        error "Daemon de Docker NO responde. Intentando iniciar..."
        sudo systemctl start docker
        sleep 2
        if docker info &>/dev/null; then
            ok "Docker iniciado correctamente."
        else
            error "No se pudo iniciar Docker."
            return 1
        fi
    fi
}

# ── 3. Iniciar servicios ──────────────────────────────────────────────────────
iniciar_servicios() {
    separador "3. Inicio de servicios (Docker Compose)"

    # Verificar que exista el docker-compose.yml
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        error "No se encontro $COMPOSE_FILE"
        return 1
    fi

    info "Construyendo e iniciando contenedores..."
    log "INFO" "Ejecutando docker-compose up"

    if docker-compose -f "$COMPOSE_FILE" up -d --build >> "$LOG_FILE" 2>&1; then
        ok "Contenedores iniciados correctamente."
    else
        error "Error al iniciar contenedores. Ver log: $LOG_FILE"
        return 1
    fi

    # Esperar que los servicios levanten
    info "Esperando 10 segundos a que los servicios arranquen..."
    sleep 10

    # Mostrar estado de los contenedores
    echo ""
    docker-compose -f "$COMPOSE_FILE" ps
    echo ""
    log "OK" "Contenedores activos"
}

# ── 4. Monitorear recursos ────────────────────────────────────────────────────
monitorear_recursos() {
    separador "4. Monitoreo de recursos del sistema"

    # CPU — porcentaje de uso
    local cpu_uso
    cpu_uso=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 2>/dev/null || echo "N/A")
    echo -e "  CPU en uso:      ${NEGRITA}${cpu_uso}%${RESET}"
    log "INFO" "CPU: $cpu_uso%"

    # Memoria RAM
    local mem_info
    mem_info=$(free -m | grep "^Mem:")
    local mem_total mem_usado mem_libre mem_porc
    mem_total=$(echo "$mem_info" | awk '{print $2}')
    mem_usado=$(echo "$mem_info" | awk '{print $3}')
    mem_libre=$(echo "$mem_info" | awk '{print $4}')
    mem_porc=$(awk "BEGIN {printf \"%.1f\", $mem_usado/$mem_total*100}")
    echo -e "  RAM total:       ${NEGRITA}${mem_total} MB${RESET}"
    echo -e "  RAM en uso:      ${NEGRITA}${mem_usado} MB (${mem_porc}%)${RESET}"
    echo -e "  RAM libre:       ${NEGRITA}${mem_libre} MB${RESET}"
    log "INFO" "RAM: $mem_usado/$mem_total MB ($mem_porc%)"

    # Disco
    local disco_info
    disco_info=$(df -h / | tail -1)
    local disco_total disco_usado disco_libre disco_porc
    disco_total=$(echo "$disco_info" | awk '{print $2}')
    disco_usado=$(echo "$disco_info" | awk '{print $3}')
    disco_libre=$(echo "$disco_info" | awk '{print $4}')
    disco_porc=$(echo "$disco_info"  | awk '{print $5}')
    echo -e "  Disco total:     ${NEGRITA}${disco_total}${RESET}"
    echo -e "  Disco en uso:    ${NEGRITA}${disco_usado} (${disco_porc})${RESET}"
    echo -e "  Disco libre:     ${NEGRITA}${disco_libre}${RESET}"
    log "INFO" "Disco: $disco_usado/$disco_total ($disco_porc)"

    # Uptime
    local uptime_info
    uptime_info=$(uptime -p 2>/dev/null || uptime)
    echo -e "  Uptime:          ${NEGRITA}${uptime_info}${RESET}"
    log "INFO" "Uptime: $uptime_info"

    # Estadisticas de contenedores Docker (si corre)
    if docker info &>/dev/null; then
        echo ""
        info "Recursos de contenedores:"
        docker stats --no-stream --format "    {{.Name}}: CPU {{.CPUPerc}} · RAM {{.MemUsage}}" 2>/dev/null \
            || warn "No hay contenedores corriendo."
    fi
}

# ── 5. Verificar estado de servicios ─────────────────────────────────────────
verificar_servicios() {
    separador "5. Estado de los servicios"

    # Servicios del sistema
    local servicios=("ssh" "ufw" "docker")
    for srv in "${servicios[@]}"; do
        if systemctl is-active --quiet "$srv" 2>/dev/null; then
            ok "Servicio '$srv' activo."
        else
            warn "Servicio '$srv' NO activo o no instalado."
        fi
    done

    echo ""

    # Contenedores del proyecto
    if comando_existe docker && docker info &>/dev/null; then
        info "Estado de contenedores:"
        docker-compose -f "$COMPOSE_FILE" ps 2>/dev/null \
            || warn "No se pudo obtener estado (docker-compose.yml no encontrado o proyecto no levantado)."
    fi

    # Puertos abiertos relevantes
    echo ""
    info "Puertos del proyecto en uso:"
    ss -tlnp 2>/dev/null | grep -E ':(80|3000|5432)\s' \
        || netstat -tlnp 2>/dev/null | grep -E ':(80|3000|5432)\s' \
        || warn "No se pudo listar puertos (instalar ss o netstat)."
    log "OK" "Verificacion de servicios completada"
}

# ── 6. Backup de la base de datos ─────────────────────────────────────────────
backup_base_datos() {
    separador "6. Backup de base de datos"

    local backup_dir="$PROYECTO_DIR/backups"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local archivo="$backup_dir/backup_${timestamp}.sql"

    mkdir -p "$backup_dir"

    # Verificar que el contenedor de DB este corriendo
    if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "pi_db"; then
        error "El contenedor pi_db no esta corriendo. Inicia el proyecto primero."
        return 1
    fi

    info "Generando backup de PostgreSQL..."
    if docker exec pi_db pg_dump -U admin taskdb > "$archivo" 2>>"$LOG_FILE"; then
        local tamanio
        tamanio=$(du -sh "$archivo" | cut -f1)
        ok "Backup guardado: $archivo ($tamanio)"
        log "OK" "Backup exitoso: $archivo"
    else
        error "Fallo al generar backup."
        log "ERROR" "Fallo backup de base de datos"
        return 1
    fi
}

# ── 7. Detener servicios ──────────────────────────────────────────────────────
detener_servicios() {
    separador "7. Deteniendo servicios"
    info "Deteniendo contenedores..."
    if docker-compose -f "$COMPOSE_FILE" down >> "$LOG_FILE" 2>&1; then
        ok "Contenedores detenidos."
    else
        error "Error al detener contenedores."
    fi
}

# ── 8. Ver logs del proyecto ──────────────────────────────────────────────────
ver_logs() {
    separador "8. Logs recientes del proyecto"
    info "Ultimas 50 lineas del log de hoy:"
    echo ""
    tail -50 "$LOG_FILE" 2>/dev/null || warn "Log de hoy aun no existe."
    echo ""
    if docker info &>/dev/null; then
        info "Logs de contenedores (ultimas 20 lineas por contenedor):"
        for nombre in pi_frontend pi_backend pi_db; do
            if docker ps --format '{{.Names}}' | grep -q "$nombre"; then
                echo -e "\n  ${NEGRITA}--- $nombre ---${RESET}"
                docker logs --tail=20 "$nombre" 2>&1
            fi
        done
    fi
}

# ── Menu interactivo ──────────────────────────────────────────────────────────
mostrar_menu() {
    echo -e "\n${NEGRITA}╔══════════════════════════════════════════╗${RESET}"
    echo -e "${NEGRITA}║   Proyecto Integrador — Sistemas Op.     ║${RESET}"
    echo -e "${NEGRITA}╚══════════════════════════════════════════╝${RESET}\n"
    echo "  1) Actualizar sistema"
    echo "  2) Validar Docker"
    echo "  3) Iniciar servicios (docker-compose up)"
    echo "  4) Monitorear recursos del sistema"
    echo "  5) Verificar estado de servicios"
    echo "  6) Backup de base de datos"
    echo "  7) Detener servicios"
    echo "  8) Ver logs"
    echo "  9) Ejecutar TODO (setup completo)"
    echo "  0) Salir"
    echo ""
    echo -n "  Selecciona una opcion: "
}

# ── Setup completo (todas las fases) ─────────────────────────────────────────
setup_completo() {
    separador "SETUP COMPLETO — Todas las fases"
    log "INFO" "Inicio de setup completo"
    actualizar_sistema
    validar_docker
    iniciar_servicios
    monitorear_recursos
    verificar_servicios
    log "OK" "Setup completo terminado"
    ok "Setup completo finalizado. Log guardado en: $LOG_FILE"
}

# ── Punto de entrada ──────────────────────────────────────────────────────────
main() {
    inicializar_logs
    log "INFO" "Script iniciado por usuario: $(whoami)"

    # Si se pasa un argumento directo, ejecutar sin menu
    case "$1" in
        actualizar)  actualizar_sistema  ;;
        docker)      validar_docker      ;;
        iniciar)     iniciar_servicios   ;;
        monitorear)  monitorear_recursos ;;
        verificar)   verificar_servicios ;;
        backup)      backup_base_datos   ;;
        detener)     detener_servicios   ;;
        logs)        ver_logs            ;;
        todo)        setup_completo      ;;
        *)
            # Menu interactivo
            while true; do
                mostrar_menu
                read -r opcion
                echo ""
                case "$opcion" in
                    1) actualizar_sistema  ;;
                    2) validar_docker      ;;
                    3) iniciar_servicios   ;;
                    4) monitorear_recursos ;;
                    5) verificar_servicios ;;
                    6) backup_base_datos   ;;
                    7) detener_servicios   ;;
                    8) ver_logs            ;;
                    9) setup_completo      ;;
                    0) info "Hasta luego."; exit 0 ;;
                    *) warn "Opcion invalida. Intenta de nuevo." ;;
                esac
                echo ""
                read -p "  Presiona Enter para continuar..." -r
            done
            ;;
    esac

    log "INFO" "Script finalizado"
}

main "$@"
