# OMORI Patch para macOS Intel (x86_64)

Este repositorio soluciona los problemas de compatibilidad para ejecutar la versión de Steam de OMORI en ordenadores Mac con procesador Intel, actualizando NW.js, Greenworks y las librerías de Steamworks para evitar el error *"Steam has not been detected"* y fallos al iniciar.

## ¿Qué problema soluciona?

OMORI en macOS utiliza un empaquetado de 32 bits y una versión de NW.js que no es compatible con versiones modernas del sistema. Aunque existen otros scripts, este asegura ser robusto, completamente idempotente, e incorpora validaciones rigurosas para solucionar los 4 problemas principales que rompen el juego en Mac Intel:

1. **Pantalla negra al iniciar ("Steam has not been detected"):** Actualiza NW.js (0.98.0), Greenworks (0.20.0) y el SDK de Steamworks (1.62) para que el juego moderno pueda comunicarse con Steam de forma correcta en sistemas de 64 bits.
2. **Crasheos aleatorios por gráficos (WebGL/Canvas):** Inyecta flags seguros de Chromium (`--disable-gpu`, etc.) en `package.json` para evitar que las GPUs integradas de Intel provoquen cierres repentinos durante los combates.
3. **Cierres al intentar guardar partida o ajustes:** Moderniza la forma en que el juego usa el sistema de archivos mediante un Polyfill de Node.js (`node-polyfill-patch.js`), reparando las escrituras "numéricas" que Node 20 ya no soporta.
4. **Crash fatal al seleccionar "New Game" o "Continue" (Invalid key length):** El juego original intenta leer su clave secreta de encriptación desde los argumentos de lanzamiento de la aplicación (`argv`). Sin embargo, en macOS, Steam y Finder suelen inyectar un argumento extra (`-psn_0_...`) al abrir el juego. El motor de OMORI leía esa "basura" junto con la clave, corrompiéndola y provocando un error fatal al intentar desencriptar el primer mapa. Este parche limpia y aísla la clave de 32 caracteres para asegurar un inicio perfecto.
Además, el parche crea archivos iniciales vitales como `CUTSCENE.json` para prevenir errores de *"archivo no encontrado"* en instalaciones limpias.

La combinación usada por el parche es:

- NW.js `0.98.0` para macOS x64.
- Greenworks `0.20.0`, compilado para NW.js `0.98.0`.
- Steamworks SDK `1.62`, obtenido desde `steamworks-sys` `0.12.0`, para que `libsteam_api.dylib` exponga las interfaces que Greenworks `0.20.0` espera (`SteamUser023` y `SteamFriends018`).

## ⚠️ EXCLUSIVO para Mac Intel x86_64

**Este script es solo para Mac Intel x86_64, no funciona en Apple Silicon (M1/M2/M3, etc.).**
Para verificar la arquitectura de tu procesador, puedes ejecutar:

```bash
uname -m
# Debería devolver: x86_64

sysctl -n machdep.cpu.brand_string
# Debería mencionar Intel
```

## Instrucciones

1. Instala OMORI desde Steam.
2. Abre la terminal en tu Mac.

### Opción 1: Ejecución directa (Rápida)
Puedes ejecutar el parche directamente desde este repositorio *(asegúrate de cambiar la URL por la de tu repositorio si has hecho un fork)*:
```bash
curl -fsSL https://raw.githubusercontent.com/leandro754/omori-patch-mac-intel/main/install.sh | bash
```

### Opción 2: Clonar el repositorio (Recomendado y Seguro)
Lo más seguro es clonar el repositorio, revisar el código por ti mismo y ejecutar el script localmente:
```bash
git clone https://github.com/leandro754/omori-patch-mac-intel.git
cd omori-patch-mac-intel
chmod +x install.sh scripts/patch-omori-intel-macos.sh
./install.sh
```

### Usar una ruta personalizada de OMORI
Si no tienes OMORI instalado en la ruta por defecto de tu usuario, puedes especificar la ruta asignando la variable `OMORI_DIR`:
```bash
OMORI_DIR="/ruta/a/OMORI" ./install.sh
```

## Qué hacer si falla

- **No usar el parche de Apple Silicon en Intel:** Si lo hiciste por error, deberás reinstalar el juego.
- **Verificar la integridad desde Steam:** Si por cualquier motivo la aplicación queda en un estado corrupto, ve a Steam -> Click derecho en OMORI -> Propiedades -> Archivos Instalados -> Verificar integridad de los archivos del juego.
- **Correr de nuevo el script:** Luego de verificar en Steam, vuelve a ejecutar este script para aplicar el parche de nuevo.
- **Cómo comprobar que Greenworks está bien:**
  Puedes verificar con el siguiente comando:
  ```bash
  file "OMORI.app/Contents/Resources/app.nw/js/libs/lib/greenworks-osx.node"
  grep '"chromium-args"' "OMORI.app/Contents/Resources/app.nw/package.json"
  grep -F 'match(/[0-9a-fA-F]{32}/)' "OMORI.app/Contents/Resources/app.nw/js/rpg_managers.js"
  grep "node-polyfill-patch" "OMORI.app/Contents/Resources/app.nw/js/libs/greenworks.js"
  grep -E "SteamUser023|SteamFriends018" "OMORI.app/Contents/Resources/app.nw/js/libs/lib/libsteam_api.dylib"
  ```
  El `.node` debe decir Mach-O, no ASCII text. `package.json` debe contener `--disable-gpu`, `rpg_managers.js` debe extraer la clave de Steam con un bloque hexadecimal de 32 caracteres, `greenworks.js` debe cargar `node-polyfill-patch`, y la dylib debe mostrar `SteamUser023` y `SteamFriends018`. Nuestro script hace estas verificaciones por ti obligatoriamente.

## Advertencia
- Este repositorio **NO** incluye el juego OMORI y no piratea absolutamente nada. Requiere una copia legítima del juego de Steam.
- Después de actualizar OMORI o verificar la integridad del juego desde Steam, tendrás que **reaplicar este parche** (ejecutarlo nuevamente), ya que Steam reemplazará las modificaciones por los archivos originales obsoletos.
