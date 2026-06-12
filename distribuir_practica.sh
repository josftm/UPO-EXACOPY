#!/bin/bash
# =============================================================================
# distribuir_practica.sh
# Distribución masiva y asíncrona de un archivo comprimido a equipos remotos
# Uso: ./distribuir_practica.sh <archivo_comprimido> <IP_inicial> <IP_final>
# Ejemplo: ./distribuir_practica.sh practica1.tar.gz 192.168.1.1 192.168.1.30
# =============================================================================

# --- Colores ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- Argumentos ---
if [ "$#" -ne 3 ]; then
    echo -e "${YELLOW}Uso: $0 <archivo_comprimido> <IP_inicial> <IP_final>${NC}"
    echo -e "Ejemplo: $0 practica1.tar.gz 192.168.1.1 192.168.1.30"
    exit 1
fi

ARCHIVO="$1"
IP_START="$2"
IP_END="$3"

# --- Verificar que el archivo existe ---
if [ ! -f "$ARCHIVO" ]; then
    echo -e "${RED}Error: El archivo '$ARCHIVO' no existe o no es un fichero regular.${NC}"
    exit 1
fi

# --- Solicitar nombre de carpeta destino ---
echo -e "${BLUE}Introduce el nombre de la carpeta de destino en el Escritorio de los alumnos:${NC}"
read -rp "  Nombre de carpeta: " FOLDER_NAME

if [ -z "$FOLDER_NAME" ]; then
    echo -e "${RED}Error: El nombre de carpeta no puede estar vacío.${NC}"
    exit 1
fi

# --- Solicitar credenciales SSH (una sola vez) ---
echo -e "${BLUE}Introduce las credenciales SSH para los equipos remotos:${NC}"
read -rp "  Usuario: " SSH_USER
read -rsp "  Contraseña: " SSH_PASS
echo ""

# --- Preparación de logs ---
LOG_DIR="/tmp/distribuir_practica_logs"
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
# Función de copia para un único host (se lanza en background)
# =============================================================================
copy_to_host() {
    local IP="$1"
    local LOG="${LOG_DIR}/copy_${IP//./_}.log"
    local NOMBRE_ARCHIVO
    NOMBRE_ARCHIVO=$(basename "$ARCHIVO")
    local START_TIME
    START_TIME=$(date +%s)

    local SSH_OPTS=(
        -o StrictHostKeyChecking=no
        -o UserKnownHostsFile=/dev/null
        -o ConnectTimeout=15
        -o ServerAliveInterval=30
    )

    # Crear carpeta y transferir el archivo en una sola conexión SSH.
    # El archivo se envía por stdin y se guarda con cat en el destino.
    # $HOME se expande en el shell remoto; no hay ambigüedad con ~.
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
            echo "  EQUIPO: ${IP}  |  Código de salida: ${EXIT_CODE}  |  $(date '+%Y-%m-%d %H:%M:%S')"
            echo "======================================================"
            cat "$LOG"
            echo ""
        } >> "$ERROR_LOG"
    fi
}

# =============================================================================
# Bucle principal: lanzar copias en paralelo
# =============================================================================
TOTAL=$(( END_OCT - START_OCT + 1 ))
NOMBRE_ARCHIVO=$(basename "$ARCHIVO")

echo -e "${BLUE}"
echo "======================================================"
echo "  Distribución masiva de práctica"
echo "  Archivo:  ${NOMBRE_ARCHIVO}"
echo "  Destino:  ~/Escritorio/${FOLDER_NAME}/"
echo "  Rango:    ${IP_START} → ${IP_END}  (${TOTAL} equipos)"
echo "  Usuario SSH: ${SSH_USER}"
echo "  Logs: ${LOG_DIR}/"
echo "======================================================"
echo -e "${NC}"

declare -A JOB_PIDS

for OCT in $(seq "$START_OCT" "$END_OCT"); do
    IP="${BASE_NET}.${OCT}"
    echo -e "${BLUE}▶ Enviando a ${IP}...${NC}"
    copy_to_host "$IP" &
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
    echo -e "${GREEN}  ✔ Archivo distribuido a todos los equipos con éxito.${NC}"
else
    echo -e "${RED}  ✘ ${FAILED} equipo(s) fallaron. Log consolidado:${NC}"
    echo -e "${RED}     ${ERROR_LOG}${NC}"
fi
echo -e "${BLUE}======================================================${NC}"
