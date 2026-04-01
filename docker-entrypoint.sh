#!/bin/sh
set -e

# Directorios y archivos
DATA_DIR="/data"
UTILS_DIR="/app/utils"
CONFIG_FILE="user-config.json"
AUTH_FILE="auth-users.json"

echo "[entrypoint] Iniciando configuración de persistencia..."

# Asegurar que el directorio /data existe (en Fly.io ya debería estar montado)
if [ ! -d "$DATA_DIR" ]; then
    echo "[entrypoint] Creando directorio $DATA_DIR..."
    mkdir -p "$DATA_DIR"
fi

# Función para manejar la persistencia de un archivo mediante symlinks
setup_persistence() {
    FILENAME=$1
    SRC="$UTILS_DIR/$FILENAME"
    DEST="$DATA_DIR/$FILENAME"

    echo "[entrypoint] Configurando persistencia para $FILENAME..."

    # 1. Si el archivo existe en /data, lo usamos como fuente de verdad.
    # 2. Si no existe en /data pero sí en /app/utils, lo migramos a /data.
    if [ ! -f "$DEST" ] && [ -f "$SRC" ]; then
        echo "[entrypoint] Migrando $FILENAME inicial a $DATA_DIR..."
        cp "$SRC" "$DEST"
    fi

    # 3. Si después de lo anterior el archivo existe en /data, creamos el symlink.
    if [ -f "$DEST" ]; then
        # Eliminar el archivo original o symlink previo en /app/utils para evitar conflictos
        rm -f "$SRC"
        # Crear el enlace simbólico para que la app lea de /app/utils pero escriba en /data
        ln -s "$DEST" "$SRC"
        echo "[entrypoint] Symlink creado: $SRC -> $DEST"
    else
        echo "[entrypoint] Advertencia: No se encontró $FILENAME para persistir."
    fi
}

# Configurar persistencia para los archivos clave
setup_persistence "$CONFIG_FILE"
setup_persistence "$AUTH_FILE"

# Ejecutar el comando original
echo "[entrypoint] Iniciando aplicación..."
exec "$@"
