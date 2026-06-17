#!/bin/bash
# =============================================================================
# distribuir_practica.sh
# Distribución o eliminación masiva y asíncrona de prácticas en equipos remotos
#
# Uso:
#   ./distribuir_practica.sh -d <archivo_comprimido> <IP_inicial> <IP_final>
#   ./distribuir_practica.sh -e <IP_inicial> <IP_final>
#
# Opciones:
#   -d  Distribuir: copia el archivo en ~/Escritorio/<carpeta>/ de cada equipo
#   -e  Eliminar:   borra ~/Escritorio/<carpeta>/ de cada equipo
#
# Ejemplos:
#   ./distribuir_practica.sh -d practica1.tar.gz 192.168.1.1 192.168.1.30
#   ./distribuir_practica.sh -e 192.168.1.1 192.168.1.30
# =============================================================================

# --- Colores ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- Uso ---
usage() {
    echo -e "${YELLOW}Uso:${NC}"
    echo -e "  $0 -d <archivo_comprimido> <IP_inicial> <IP_final>"
    echo -e "  $0 -e <IP_inicial> <IP_final>"
    echo ""
    echo -e "${YELLOW}Opciones:${NC}"
    echo -e "  -d  Distribuir un archivo comprimido al Escritorio de los alumnos"
    echo -e "  -e  Eliminar la carpeta de práctica del Escritorio de los alumnos"
    exit 1
}

# --- Parseo de la bandera ---
if [ "$#" -lt 1 ]; then
    usage
fi

MODE="$1"
shift

case "$MODE" in
    -d)
        if [ "$#" -ne 3 ]; then
            echo -e "${RED}Error: -d requiere <archivo_comprimido> <IP_inicial> <IP_final>${NC}"
            usage
        fi
        ARCHIVO="$1"
        IP_START="$2"
        IP_END="$3"
        if [ ! -f "$ARCHIVO" ]; then
            echo -e "${RED}Error: El archivo '$ARCHIVO' no existe o no es un fichero regular.${NC}"
            exit 1
        fi
        ;;
    -e)
        if [ "$#" -ne 2 ]; then
            echo -e "${RED}Error: -e requiere <IP_inicial> <IP_final>${NC}"
            usage
        fi
        IP_START="$1"
        IP_END="$2"
        ;;
    *)
        echo -e "${RED}Error: opción desconocida '$MODE'${NC}"
        usage
        ;;
esac

# --- Solicitar nombre de carpeta destino ---
echo -e "${BLUE}Introduce el nombre de la carpeta en el Escritorio de los alumnos:${NC}"
read -rp "  Nombre de carpeta: " FOLDER_NAME

if [ -z "$FOLDER_NAME" ]; then
    echo -e "${RED}Error: El nombre de carpeta no puede estar vacío.${NC}"
    exit 1
fi

# --- Confirmación adicional en modo eliminación ---
if [ "$MODE" = "-e" ]; then
    echo -e "${RED}⚠  Se eliminará ~/Escritorio/${FOLDER_NAME}/ en todos los equipos del rango.${NC}"
    read -rp "  ¿Confirmar? (s/N): " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[sS]$ ]]; then
        echo "Operación cancelada."
        exit 0
    fi
fi

# --- Solicitar credenciales SSH (una sola vez) ---
echo -e "${BLUE}Introduce las credenciales SSH para los equipos remotos:${NC}"
read -rp "  Usuario: " SSH_USER
read -rsp "  Contraseña: " SSH_PASS
echo ""

# --- Preparación de logs ---
LOG_DIR="/tmp/gestionar_practica_logs"
ERROR_LOG="${LOG_DIR}/errores.log"
mkdir -p "$LOG_DIR"
> "$ERROR_LOG"

# --- Extraer base de red y octetos ---
BASE_NET=$(echo "$IP_START" | cut -d'.' -f1-3)
START_OCT=$(echo "$IP_START" | cut -d'.' -f4)
END_OCT=$(echo "$IP_END" | cut -d'.' -f4)

if [ "$START_OCT" -gt "$END_OCT" ]; then
    echo -e "${RED}Error: La IP inicial debe ser menor o igual que la IP final.${NC}"
    exit 1
fi

# --- Verificar sshpass en el equipo del profesor ---
if ! command -v sshpass &>/dev/null; then
    echo -e "${YELLOW}[AVISO] sshpass no encontrado. Instalando en este equipo...${NC}"
    sudo apt-get install -y sshpass
fi

# =============================================================================
# Opciones SSH comunes
# =============================================================================
SSH_OPTS=(
    -o StrictHostKeyChecking=no
    -o UserKnownHostsFile=/dev/null
    -o ConnectTimeout=15
    -o ServerAliveInterval=30
)

# =============================================================================
# Función: distribuir archivo a un host
# =============================================================================
copy_to_host() {
    local IP="$1"
    local LOG="${LOG_DIR}/copy_${IP//./_}.log"
    local NOMBRE_ARCHIVO
    NOMBRE_ARCHIVO=$(basename "$ARCHIVO")
    local START_TIME
    START_TIME=$(date +%s)

    local EXIT_CODE=0
    sshpass -p "$SSH_PASS" ssh "${SSH_OPTS[@]}" \
        "$SSH_USER@$IP" \
        "mkdir -p \"\$HOME/Escritorio/${FOLDER_NAME}\" && cat > \"\$HOME/Escritorio/${FOLDER_NAME}/${NOMBRE_ARCHIVO}\"" \
        < "$ARCHIVO" >> "$LOG" 2>&1 || EXIT_CODE=$?

    local END_TIME
    END_TIME=$(date +%s)
    local ELAPSED=$(( END_TIME - START_TIME ))

    if [ "$EXIT_CODE" -eq 0 ]; then
        echo -e "${GREEN}✔ [$(date '+%H:%M:%S')] ${IP} — copia completada (${ELAPSED}s).${NC}"
    else
        echo -e "${RED}✘ [$(date '+%H:%M:%S')] ${IP} — falló (código $EXIT_CODE, ${ELAPSED}s).${NC}"
        {
            echo "======================================================"
            echo "  EQUIPO: ${IP}  |  Código: ${EXIT_CODE}  |  $(date '+%Y-%m-%d %H:%M:%S')"
            echo "======================================================"
            cat "$LOG"
            echo ""
        } >> "$ERROR_LOG"
    fi
}

# =============================================================================
# Función: eliminar carpeta en un host
# =============================================================================
delete_from_host() {
    local IP="$1"
    local LOG="${LOG_DIR}/delete_${IP//./_}.log"
    local START_TIME
    START_TIME=$(date +%s)

    # Verificar primero si la carpeta existe en el equipo remoto
    local DIR_EXISTS=0
    sshpass -p "$SSH_PASS" ssh "${SSH_OPTS[@]}" \
        "$SSH_USER@$IP" \
        "test -d \"\$HOME/Escritorio/${FOLDER_NAME}\"" \
        >> "$LOG" 2>&1 || DIR_EXISTS=1

    local END_TIME
    END_TIME=$(date +%s)
    local ELAPSED=$(( END_TIME - START_TIME ))

    if [ "$DIR_EXISTS" -ne 0 ]; then
        echo -e "${YELLOW}⚠ [$(date '+%H:%M:%S')] ${IP} — la carpeta no existe, se omite (${ELAPSED}s).${NC}"
        return 0
    fi

    local EXIT_CODE=0
    sshpass -p "$SSH_PASS" ssh "${SSH_OPTS[@]}" \
        "$SSH_USER@$IP" \
        "rm -rf \"\$HOME/Escritorio/${FOLDER_NAME}\"" \
        >> "$LOG" 2>&1 || EXIT_CODE=$?

    END_TIME=$(date +%s)
    ELAPSED=$(( END_TIME - START_TIME ))

    if [ "$EXIT_CODE" -eq 0 ]; then
        echo -e "${GREEN}✔ [$(date '+%H:%M:%S')] ${IP} — carpeta eliminada (${ELAPSED}s).${NC}"
    else
        echo -e "${RED}✘ [$(date '+%H:%M:%S')] ${IP} — falló (código $EXIT_CODE, ${ELAPSED}s).${NC}"
        {
            echo "======================================================"
            echo "  EQUIPO: ${IP}  |  Código: ${EXIT_CODE}  |  $(date '+%Y-%m-%d %H:%M:%S')"
            echo "======================================================"
            cat "$LOG"
            echo ""
        } >> "$ERROR_LOG"
    fi
}

# =============================================================================
# Bucle principal: lanzar operaciones en paralelo
# =============================================================================
TOTAL=$(( END_OCT - START_OCT + 1 ))

echo -e "${BLUE}"
echo "======================================================"
if [ "$MODE" = "-d" ]; then
    echo "  Modo:     Distribución"
    echo "  Archivo:  $(basename "$ARCHIVO")"
else
    echo "  Modo:     Eliminación"
fi
echo "  Carpeta:  ~/Escritorio/${FOLDER_NAME}/"
echo "  Rango:    ${IP_START} → ${IP_END}  (${TOTAL} equipos)"
echo "  Usuario SSH: ${SSH_USER}"
echo "  Logs: ${LOG_DIR}/"
echo "======================================================"
echo -e "${NC}"

declare -A JOB_PIDS

for OCT in $(seq "$START_OCT" "$END_OCT"); do
    IP="${BASE_NET}.${OCT}"
    if [ "$MODE" = "-d" ]; then
        echo -e "${BLUE}▶ Enviando a ${IP}...${NC}"
        copy_to_host "$IP" &
    else
        echo -e "${BLUE}▶ Eliminando en ${IP}...${NC}"
        delete_from_host "$IP" &
    fi
    JOB_PIDS["$IP"]=$!
    sleep 0.3
done

echo ""
echo -e "${YELLOW}⏳ Esperando a que terminen los ${TOTAL} equipos...${NC}"
echo ""

FAILED=0
for IP in "${!JOB_PIDS[@]}"; do
    if ! wait "${JOB_PIDS[$IP]}"; then
        (( FAILED++ )) || true
    fi
done

echo ""
echo -e "${BLUE}======================================================"
if [ "$FAILED" -eq 0 ]; then
    if [ "$MODE" = "-d" ]; then
        echo -e "${GREEN}  ✔ Archivo distribuido a todos los equipos con éxito.${NC}"
    else
        echo -e "${GREEN}  ✔ Carpeta eliminada en todos los equipos con éxito.${NC}"
    fi
else
    echo -e "${RED}  ✘ ${FAILED} equipo(s) fallaron. Log consolidado:${NC}"
    echo -e "${RED}     ${ERROR_LOG}${NC}"
fi
echo -e "${BLUE}======================================================${NC}"
