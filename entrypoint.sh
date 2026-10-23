#!/bin/sh
set -eu

CONF="${TINYPROXY_CONF:-/etc/tinyproxy/tinyproxy.conf}"
LOG_DIR="/var/log/tinyproxy"
LOG_FILE="${LOG_DIR}/tinyproxy.log"

# --- Normalización defensiva (BOM + CRLF) ---
sed -i '1s/^\xEF\xBB\xBF//; s/\r$//' "$CONF"

# --- Puerto configurable por entorno ---
if [ -n "${PROXY_PORT:-}" ]; then
    sed -i "s/^Port [0-9]*/Port ${PROXY_PORT}/" "$CONF"
fi

# --- Redes permitidas (coma o espacio) ---
if [ -n "${ALLOW_NETWORKS:-}" ]; then
    sed -i '/^Allow /d' "$CONF"
    printf '%s\n' "$ALLOW_NETWORKS" | tr ', ' '\n\n' | while read -r net; do
        [ -n "$net" ] && printf 'Allow %s\n' "$net" >> "$CONF"
    done
fi

# --- Credenciales opcionales (BasicAuth) ---
if [ -n "${PROXY_USER:-}" ] || [ -n "${PROXY_PASSWORD:-}" ]; then
    if [ -z "${PROXY_USER:-}" ] || [ -z "${PROXY_PASSWORD:-}" ]; then
        echo "[entrypoint] WARN: PROXY_USER y PROXY_PASSWORD deben definirse juntos. BasicAuth omitido." >&2
    else
        sed -i '/^BasicAuth /d' "$CONF"
        printf 'BasicAuth %s %s\n' "$PROXY_USER" "$PROXY_PASSWORD" >> "$CONF"
    fi
fi

# --- Log: archivo REGULAR propiedad de tinyproxy ---
mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
chown tinyproxy:tinyproxy "$LOG_DIR" "$LOG_FILE"
chmod 750 "$LOG_DIR"
chmod 640 "$LOG_FILE"

sed -i '/^LogFile /d' "$CONF"
printf 'LogFile "%s"\n' "$LOG_FILE" >> "$CONF"

# --- Volcar el archivo a stdout (tail -F tolera truncado/rotación) ---
tail -F -n +1 "$LOG_FILE" > /dev/stdout &
TAIL_PID=$!

echo "[entrypoint] Iniciando tinyproxy con $CONF" >&2

# --- Arranque con forwarding de señales ---
"$@" &
MAIN_PID=$!

forward() {
    kill -TERM "$MAIN_PID" 2>/dev/null || true
}
trap forward TERM INT

set +e
wait "$MAIN_PID"
STATUS=$?
set -e

kill "$TAIL_PID" 2>/dev/null || true
exit "$STATUS"