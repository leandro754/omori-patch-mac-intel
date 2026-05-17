#!/usr/bin/env bash
set -euo pipefail

# Asegurate de cambiar esto a tu usuario/repo si haces un fork o subes esto a tu GitHub
REPO_URL="https://raw.githubusercontent.com/leandro754/omori-patch-mac-intel/main"

echo "=== OMORI macOS Intel x86_64 Patcher ==="

# Si el script se ejecuta dentro del directorio clonado, usar el archivo local
if [ -f "scripts/patch-omori-intel-macos.sh" ]; then
    echo "Ejecutando script local..."
    bash scripts/patch-omori-intel-macos.sh
else
    # Si se ejecuta mediante curl, descargar el script principal
    echo "Descargando y ejecutando script desde el repositorio remoto..."
    TMP=$(mktemp -d)
    trap 'rm -rf "$TMP"' EXIT
    curl -fL --retry 3 --connect-timeout 20 "$REPO_URL/scripts/patch-omori-intel-macos.sh?v=$RANDOM" -o "$TMP/patch-omori-intel-macos.sh"
    bash "$TMP/patch-omori-intel-macos.sh"
fi
