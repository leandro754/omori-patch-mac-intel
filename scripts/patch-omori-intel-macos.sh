#!/usr/bin/env bash
set -euo pipefail

echo "Iniciando parcheo de OMORI para macOS Intel x86_64..."

APP_ID="1150690"
NWJS_VERSION="0.98.0"
GREENWORKS_VERSION="0.20.0"
STEAMWORKS_SYS_VERSION="0.12.0"
SAFE_CHROMIUM_ARGS="--disable-gpu --disable-gpu-compositing --disable-gpu-rasterization --disable-accelerated-2d-canvas --disable-zero-copy --disable-gpu-memory-buffer-video-frames"

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
CURL_OPTS=(-fL --retry 3 --connect-timeout 20)

# 11. Descargas requeridas
echo "Descargando NW.js Intel x64..."
curl "${CURL_OPTS[@]}" -o nwjs.zip "https://dl.nwjs.io/v$NWJS_VERSION/nwjs-v$NWJS_VERSION-osx-x64.zip"

echo "Descargando Greenworks oficial..."
curl "${CURL_OPTS[@]}" -o greenworks.zip "https://github.com/greenheartgames/greenworks/releases/download/v$GREENWORKS_VERSION/greenworks-v$GREENWORKS_VERSION-nw-v$NWJS_VERSION-osx.zip"

echo "Descargando Steamworks API compatible con Greenworks..."
curl "${CURL_OPTS[@]}" -A "omori-patch-mac-intel" -o steamworks-sys.crate "https://static.crates.io/crates/steamworks-sys/steamworks-sys-$STEAMWORKS_SYS_VERSION.crate"

# 12. Verificar los ZIPs antes de extraer
echo "Verificando integridad de los archivos descargados..."
for zipfile in nwjs.zip greenworks.zip; do
    if ! file "$zipfile" | grep -q "Zip archive data"; then
        echo "ERROR: $zipfile no es un archivo ZIP válido."
        exit 1
    fi
    if ! unzip -tq "$zipfile"; then
        echo "ERROR: $zipfile está corrupto."
        exit 1
    fi
done

if ! file steamworks-sys.crate | grep -Eq "gzip compressed data|tar archive"; then
    echo "ERROR: steamworks-sys.crate no es un tarball válido."
    exit 1
fi

if ! tar -tzf steamworks-sys.crate >/dev/null; then
    echo "ERROR: steamworks-sys.crate está corrupto."
    exit 1
fi

# 13. Extraer con -oq
echo "Extrayendo archivos..."
unzip -oq nwjs.zip
unzip -oq greenworks.zip
tar -xzf steamworks-sys.crate

# Preparar nueva app en temporal
NEW_APP="$TMP/OMORI.app"
echo "Armando nueva OMORI.app..."

# 14. Copiar nwjs.app como nueva OMORI.app
cp -R "nwjs-v$NWJS_VERSION-osx-x64/nwjs.app" "$NEW_APP"

# 15. Copiar app.nw desde el backup original
echo "Copiando datos del juego (esto puede tardar unos segundos)..."
mkdir -p "$NEW_APP/Contents/Resources/app.nw"
cp -R "$BACKUP_DIR/Contents/Resources/app.nw/." "$NEW_APP/Contents/Resources/app.nw/"

# 16. Copiar app.icns si existe
if [ -f "$BACKUP_DIR/Contents/Resources/app.icns" ]; then
    cp "$BACKUP_DIR/Contents/Resources/app.icns" "$NEW_APP/Contents/Resources/"
fi

PKG_JSON="$NEW_APP/Contents/Resources/app.nw/package.json"
if [ -f "$PKG_JSON" ]; then
    echo "Aplicando flags seguros de Chromium para Intel GPU..."
    if ! grep -q '"chromium-args"' "$PKG_JSON"; then
        echo "ERROR: package.json no contiene chromium-args para reemplazar."
        exit 1
    fi

    SAFE_CHROMIUM_ARGS="$SAFE_CHROMIUM_ARGS" perl -0pi -e 'BEGIN { $args = $ENV{"SAFE_CHROMIUM_ARGS"}; } s#("chromium-args"\s*:\s*")[^"]*(")#$1$args$2#' "$PKG_JSON"
fi

RPG_MANAGERS="$NEW_APP/Contents/Resources/app.nw/js/rpg_managers.js"
if [ -f "$RPG_MANAGERS" ]; then
    perl -0pi -e 's#let steamkey = String\(window\.nw\.App\.argv\)\.replace\("--", ""\);#let steamkey = (window.nw.App.argv || []).map(String).map(arg => arg.replace(/^--/, "")).find(arg => arg.length === 32 && !/[^0-9a-fA-F]/.test(arg)) || String(window.nw.App.argv).replace("--", "");#g' "$RPG_MANAGERS"
fi

LIBS_DIR="$NEW_APP/Contents/Resources/app.nw/js/libs"
mkdir -p "$LIBS_DIR/lib"

GW_DIR="$TMP/greenworks-v$GREENWORKS_VERSION-nw-v$NWJS_VERSION-osx"
if [ ! -f "$GW_DIR/greenworks.js" ]; then
    GW_DIR="$TMP"
fi

STEAMWORKS_DIR="$TMP/steamworks-sys-$STEAMWORKS_SYS_VERSION"

# 18. Copiar greenworks oficial a libs (greenworks.js requiere que el .node esté en /lib/)
if [ ! -f "$GW_DIR/greenworks.js" ] || [ ! -f "$GW_DIR/lib/greenworks-osx.node" ]; then
    echo "ERROR: Greenworks no se extrajo con la estructura esperada."
    exit 1
fi

cp "$GW_DIR/greenworks.js" "$LIBS_DIR/greenworks.js"
cp "$GW_DIR/lib/greenworks-osx.node" "$LIBS_DIR/lib/greenworks-osx.node"

# 18b. Cargar polyfill para escrituras numericas de Node moderno.
cat > "$LIBS_DIR/node-polyfill-patch.js" <<'NODE_POLYFILL'
(function patchFsNumericWrites() {
    const fs = require("fs");
    if (fs.__omoriNumericWritePatch) return;

    const normalizeData = function(data) {
        return typeof data === "number" ? data.toString() : data;
    };

    const oldWriteFile = fs.writeFile;
    fs.writeFile = function(path, data, options, callback) {
        return oldWriteFile.call(this, path, normalizeData(data), options, callback);
    };

    const oldWriteFileSync = fs.writeFileSync;
    fs.writeFileSync = function(path, data, options) {
        return oldWriteFileSync.call(this, path, normalizeData(data), options);
    };

    fs.__omoriNumericWritePatch = true;
})();
NODE_POLYFILL

GREENWORKS_PATCHED="$TMP/greenworks.js.with-polyfill"
{
    printf '%s\n\n' 'require("./node-polyfill-patch");'
    cat "$LIBS_DIR/greenworks.js"
} > "$GREENWORKS_PATCHED"
mv "$GREENWORKS_PATCHED" "$LIBS_DIR/greenworks.js"

# 19. Copiar Steamworks API a /lib/ junto al .node y a MacOS
STEAM_API="$STEAMWORKS_DIR/lib/steam/redistributable_bin/osx/libsteam_api.dylib"
SDK_TICKET="$STEAMWORKS_DIR/lib/steam/public/steam/lib/osx/libsdkencryptedappticket.dylib"

if [ ! -f "$STEAM_API" ]; then
    echo "ERROR: Falta libsteam_api.dylib de Steamworks SDK 1.62."
    exit 1
fi

if [ ! -f "$SDK_TICKET" ]; then
    echo "ERROR: Falta libsdkencryptedappticket.dylib de Steamworks SDK 1.62."
    exit 1
fi

if ! grep -q "SteamUser023" "$STEAM_API"; then
    echo "ERROR: libsteam_api.dylib no expone SteamUser023; no es compatible con Greenworks $GREENWORKS_VERSION."
    exit 1
fi

if ! grep -q "SteamFriends018" "$STEAM_API"; then
    echo "ERROR: libsteam_api.dylib no expone SteamFriends018; no es compatible con Greenworks $GREENWORKS_VERSION."
    exit 1
fi

cp "$STEAM_API" "$LIBS_DIR/lib/"
cp "$SDK_TICKET" "$LIBS_DIR/lib/"
cp "$STEAM_API" "$NEW_APP/Contents/MacOS/"
cp "$SDK_TICKET" "$NEW_APP/Contents/MacOS/"

# 21. Crear steam_appid.txt
printf '%s\n' "$APP_ID" > "$NEW_APP/Contents/MacOS/steam_appid.txt"
printf '%s\n' "$APP_ID" > "$NEW_APP/Contents/Resources/app.nw/steam_appid.txt"
printf '%s\n' "$APP_ID" > "$LIBS_DIR/lib/steam_appid.txt"

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
printf '%s\n' "$APP_ID" > "$OMORI_DIR/steam_appid.txt"

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
file "$APP_DIR/Contents/Resources/app.nw/js/libs/lib/greenworks-osx.node"
file "$APP_DIR/Contents/Resources/app.nw/js/libs/lib/libsteam_api.dylib"
file "$APP_DIR/Contents/Resources/app.nw/js/libs/lib/libsdkencryptedappticket.dylib"
ls -lh "$APP_DIR/Contents/Resources/app.nw/js/libs" | grep -E "greenworks|node-polyfill" || true
ls -lh "$APP_DIR/Contents/Resources/app.nw/js/libs/lib" | grep -E "greenworks|steam|sdk" || true
grep -n '"chromium-args"' "$APP_DIR/Contents/Resources/app.nw/package.json" || true

if file "$APP_DIR/Contents/Resources/app.nw/js/libs/lib/greenworks-osx.node" | grep -qi "ASCII text"; then
    echo "ERROR: Greenworks se descargó mal; no es binario Mach-O."
    exit 1
fi

if ! grep -q -- "--disable-gpu" "$APP_DIR/Contents/Resources/app.nw/package.json"; then
    echo "ERROR: package.json no tiene los flags seguros de Chromium para Intel GPU."
    exit 1
fi

if grep -q -- "--enable-gpu-rasterization" "$APP_DIR/Contents/Resources/app.nw/package.json"; then
    echo "ERROR: package.json conserva flags GPU incompatibles con este parche."
    exit 1
fi

if ! grep -q "arg.length === 32" "$APP_DIR/Contents/Resources/app.nw/js/rpg_managers.js"; then
    echo "ERROR: rpg_managers.js no tiene el parser robusto de Steam key."
    exit 1
fi

if ! grep -q "node-polyfill-patch" "$APP_DIR/Contents/Resources/app.nw/js/libs/greenworks.js"; then
    echo "ERROR: greenworks.js no está cargando el polyfill de escritura para Node moderno."
    exit 1
fi

if ! grep -q "SteamUser023" "$APP_DIR/Contents/Resources/app.nw/js/libs/lib/libsteam_api.dylib"; then
    echo "ERROR: libsteam_api.dylib instalada no es la versión compatible con Steamworks SDK 1.62."
    exit 1
fi

# 29. Mensaje final
echo ""
echo "Listo. Abrí Steam, esperá que esté logueado, y lanzá OMORI desde la biblioteca."
echo "No verifiques integridad después del parche porque Steam puede revertir los cambios."
