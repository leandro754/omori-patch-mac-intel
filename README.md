# OMORI Patch para macOS Intel (x86_64)

Este repositorio soluciona los problemas de compatibilidad para ejecutar la versión de Steam de OMORI en ordenadores Mac con procesador Intel, actualizando NW.js y las librerías de Steamworks para evitar el error *"Steam has not been detected"* y fallos al iniciar.

## ¿Qué problema soluciona?

OMORI en macOS utiliza un empaquetado de 32 bits y una versión de NW.js que no es compatible con versiones modernas del sistema. Aunque existen otros scripts, este asegura ser robusto, completamente idempotente, e incorpora validaciones rigurosas.
Evita problemas donde descargas mal realizadas (sin `-L`), o binarios corruptos / falsos (archivos de texto en vez de ejecutables Mach-O), terminaban corrompiendo la instalación del juego. 

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
  file "OMORI.app/Contents/Resources/app.nw/js/libs/greenworks-osx64.node"
  ```
  Debe decir Mach-O, no ASCII text. Nuestro script hace esta verificación por ti obligatoriamente.

## Advertencia
- Este repositorio **NO** incluye el juego OMORI y no piratea absolutamente nada. Requiere una copia legítima del juego de Steam.
- Después de actualizar OMORI o verificar la integridad del juego desde Steam, tendrás que **reaplicar este parche** (ejecutarlo nuevamente), ya que Steam reemplazará las modificaciones por los archivos originales obsoletos.
