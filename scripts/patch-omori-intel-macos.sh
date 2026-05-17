#!/usr/bin/env bash
set -euo pipefail

echo "Iniciando parcheo de OMORI para macOS Intel x86_64..."

# 3. Detectar arquitectura
ARCH=$(uname -m)
if [ "$ARCH" != "x86_64" ]; then
    echo "ERROR: Este script es solo para Mac Intel x86_64. Para Apple Silicon no usar este parche."
    exit 1
fi

# 4. Cerrar Steam y OMORI antes de modificar
echo "Cerrando OMORI y Steam si están abiertos..."
osascript -e 'quit app "OMORI"' >/dev/null 2>&1 || true
osascript -e 'quit app "Steam"' >/dev/null 2>&1 || true

# 5. Permitir ruta personalizada con variable
OMORI_DIR="${OMORI_DIR:-$HOME/Library/Application Support/Steam/steamapps/common/OMORI}"
APP_DIR="$OMORI_DIR/OMORI.app"

# 6. Validar que existe app.nw
if [ ! -d "$APP_DIR/Contents/Resources/app.nw" ]; then
    echo "ERROR: La instalación parece rota. Verificá integridad desde Steam y corré de nuevo este script."
    exit 1
fi

# 7. Hacer backup seguro antes de tocar nada
BACKUP_DIR="$OMORI_DIR/OMORI.pre-intelpatch.app"
if [ ! -d "$BACKUP_DIR" ]; then
    echo "Creando backup de OMORI.app original en $BACKUP_DIR..."
    cp -R "$APP_DIR" "$BACKUP_DIR"
else
    echo "El backup $BACKUP_DIR ya existe. Verificando si OMORI.app actual es válido antes de sobreescribir..."
    if [ -d "$APP_DIR/Contents/Resources/app.nw" ]; then
        echo "Usando el backup existente."
    fi
fi

# 9. Crear carpeta temporal
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"

echo "Descargando archivos necesarios..."
# 10. Descargar con curl
CURL_OPTS="-fL --retry 3 --connect-timeout 20"

# 11. Descargas requeridas
echo "Descargando NW.js Intel x64..."
curl $CURL_OPTS -o nwjs.zip "https://dl.nwjs.io/v0.98.0/nwjs-v0.98.0-osx-x64.zip"

echo "Descargando Greenworks oficial..."
curl $CURL_OPTS -o greenworks.zip "https://github.com/greenheartgames/greenworks/releases/download/v0.20.0/greenworks-v0.20.0-nw-v0.98.0-osx.zip"

echo "Descargando greenworks.js..."
curl $CURL_OPTS -o greenworks.js "https://raw.githubusercontent.com/DaCUtePotato/omori-apple-intel/master/lib/greenworks.js"

echo "Descargando node-polyfill-patch.js..."
curl $CURL_OPTS -o node-polyfill-patch.js "https://raw.githubusercontent.com/DaCUtePotato/omori-apple-intel/master/lib/node-polyfill-patch.js"

echo "Descargando Steamworks API..."
curl $CURL_OPTS -o steam.zip "https://dl.snowp.io/omori-apple-silicon/steam.zip"

# 12. Verificar los ZIPs antes de extraer
echo "Verificando integridad de los archivos descargados..."
for zipfile in nwjs.zip greenworks.zip steam.zip; do
    if ! file "$zipfile" | grep -q "Zip archive data"; then
        echo "ERROR: $zipfile no es un archivo ZIP válido."
        exit 1
    fi
    if ! unzip -tq "$zipfile"; then
        echo "ERROR: $zipfile está corrupto."
        exit 1
    fi
done

# 13. Extraer con -oq
echo "Extrayendo archivos..."
unzip -oq nwjs.zip
unzip -oq greenworks.zip
unzip -oq steam.zip

# Preparar nueva app en temporal
NEW_APP="$TMP/OMORI.app"
echo "Armando nueva OMORI.app..."

# 14. Copiar nwjs.app como nueva OMORI.app
cp -R "nwjs-v0.98.0-osx-x64/nwjs.app" "$NEW_APP"

# 15. Copiar app.nw desde el backup original
echo "Copiando datos del juego (esto puede tardar unos segundos)..."
mkdir -p "$NEW_APP/Contents/Resources/app.nw"
cp -R "$BACKUP_DIR/Contents/Resources/app.nw/"* "$NEW_APP/Contents/Resources/app.nw/"

# 16. Copiar app.icns si existe
if [ -f "$BACKUP_DIR/Contents/Resources/app.icns" ]; then
    cp "$BACKUP_DIR/Contents/Resources/app.icns" "$NEW_APP/Contents/Resources/"
fi

# 17. Buscar greenworks-osx64.node
GW_NODE=$(find "$TMP" -name "greenworks-osx64.node" -type f | grep -v "OMORI.app" | head -n 1)
if [ -z "$GW_NODE" ]; then
    echo "ERROR: No se encontró greenworks-osx64.node en lo descargado."
    exit 1
fi

LIBS_DIR="$NEW_APP/Contents/Resources/app.nw/js/libs"
mkdir -p "$LIBS_DIR"

# 18. Copiar a la carpeta libs
cp "$GW_NODE" "$LIBS_DIR/greenworks-osx64.node"

# 19. Copia de compatibilidad greenworks-osxx64.node si es referenciada
if grep -q "osxx64" greenworks.js; then
    echo "greenworks.js referencia osxx64, creando copia de compatibilidad..."
    cp "$GW_NODE" "$LIBS_DIR/greenworks-osxx64.node"
fi

# 20. Copiar resto de dependencias
cp greenworks.js "$LIBS_DIR/"
cp node-polyfill-patch.js "$LIBS_DIR/"

STEAM_API=$(find "$TMP" -name "libsteam_api.dylib" -type f | grep -v "OMORI.app" | head -n 1)
SDK_TICKET=$(find "$TMP" -name "libsdkencryptedappticket.dylib" -type f | grep -v "OMORI.app" | head -n 1)

if [ -n "$STEAM_API" ]; then 
    cp "$STEAM_API" "$LIBS_DIR/"
else 
    echo "ERROR: Falta libsteam_api.dylib."
    exit 1
fi

if [ -n "$SDK_TICKET" ]; then 
    cp "$SDK_TICKET" "$LIBS_DIR/"
fi

# 21. Crear steam_appid.txt
echo "1150690" > "$NEW_APP/Contents/MacOS/steam_appid.txt"
echo "1150690" > "$NEW_APP/Contents/Resources/app.nw/steam_appid.txt"

# 22. Aplicar fixes de guardado si los archivos existen
echo "Aplicando fixes de guardado..."
GTP_FIX=$(find "$NEW_APP/Contents/Resources/app.nw" -name "GTP_OmoriFixes.js" -type f | head -n 1)
if [ -n "$GTP_FIX" ]; then
    sed -i '' 's/DataManager.writeToFile(world, "TITLEDATA")/DataManager.writeToFile(world.toString(), "TITLEDATA")/g' "$GTP_FIX"
fi

YIN_FIX=$(find "$NEW_APP/Contents/Resources/app.nw" -name "YIN_OmoriFixes.js" -type f | head -n 1)
if [ -n "$YIN_FIX" ]; then
    sed -i '' 's/DataManager.writeToFileAsync(world, "TITLEDATA", () => {/DataManager.writeToFileAsync(world.toString(), "TITLEDATA", () => {/g' "$YIN_FIX"
fi

# 23. Ajustar Info.plist
echo "Ajustando Info.plist..."
PLIST="$NEW_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName OMORI" "$PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleName string OMORI" "$PLIST" 2>/dev/null || true

/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName OMORI" "$PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string OMORI" "$PLIST" 2>/dev/null || true

/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile app.icns" "$PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string app.icns" "$PLIST" 2>/dev/null || true

# 24. Reemplazar OMORI.app original solo cuando la nueva OMORI.app ya esté armada
echo "Instalando la nueva versión de OMORI.app..."
rm -rf "$APP_DIR"
cp -R "$NEW_APP" "$APP_DIR"

# 25, 26. Ajustar permisos y quitar cuarentena
echo "Ajustando permisos..."
xattr -cr "$APP_DIR" || true
chmod -R u+rwX "$APP_DIR"
find "$APP_DIR/Contents/MacOS" -type f -exec chmod +x {} \;

# 27. Firmar localmente
echo "Firmando ejecutable localmente..."
codesign --force --deep --sign - "$APP_DIR" || echo "ADVERTENCIA: Falló codesign, el juego podría ser bloqueado por Gatekeeper."

# 28. Verificación final obligatoria
echo "Realizando verificaciones finales..."
file "$APP_DIR/Contents/MacOS/"*
file "$APP_DIR/Contents/Resources/app.nw/js/libs/greenworks-osx64.node"
file "$APP_DIR/Contents/Resources/app.nw/js/libs/libsteam_api.dylib"
ls -lh "$APP_DIR/Contents/Resources/app.nw/js/libs" | grep -E "greenworks|steam|sdk" || true

if file "$APP_DIR/Contents/Resources/app.nw/js/libs/greenworks-osx64.node" | grep -qi "ASCII text"; then
    echo "ERROR: Greenworks se descargó mal; no es binario Mach-O."
    exit 1
fi

# 29. Mensaje final
echo ""
echo "Listo. Abrí Steam, esperá que esté logueado, y lanzá OMORI desde la biblioteca."
echo "No verifiques integridad después del parche porque Steam puede revertir los cambios."
