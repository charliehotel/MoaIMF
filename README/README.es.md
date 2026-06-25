| [🇰🇷 한국어](README.md) | [🇺🇸 English](README.en.md) | [🇯🇵 日本語](README.ja.md) | [🇨🇳 简体中文](README.zh-Hans.md) | [🇹🇼 繁體中文](README.zh-Hant.md) | [🇻🇳 Tiếng Việt](README.vi.md) | [🇫🇷 Français](README.fr.md) | [🇩🇪 Deutsch](README.de.md) | [🇪🇸 Español](README.es.md) | [🇵🇹 Português](README.pt.md) | [🇹🇭 ไทย](README.th.md) | [🇸🇦 العربية](README.ar.md) |
|---|---|---|---|---|---|---|---|---|---|---|---|

<p align="center">
  <img src="../Assets.xcassets/MoaIMF_icon.png" width="128" height="128" alt="Icono de MoaIMF">
</p>

<h1 align="center">MoaIMF</h1>

<p align="center">
  <strong>Initial. Medial. Final. Composed.</strong><br>
  Una app de barra de menús para macOS que normaliza con seguridad nombres Unicode descompuestos a NFC
</p>

<p align="center">
  <a href="#introducción">Introducción</a> ·
  <a href="#uso">Uso</a> ·
  <a href="#instalación-y-build">Instalación y build</a> ·
  <a href="#seguridad-y-privacidad">Seguridad</a> ·
  <a href="#desarrollo">Desarrollo</a>
</p>

## Introducción

MoaIMF es una app de barra de menús para macOS que normaliza nombres de archivos y carpetas en ubicaciones elegidas por el usuario a Unicode NFC. El nombre alude a reunir Initial, Medial y Final de una sílaba hangul en una forma compuesta.

En macOS, los nombres coreanos pueden guardarse en una forma descompuesta similar a NFD después de pasar por sistemas de archivos, apps, herramientas de descarga, descompresores, discos externos, NAS o sincronización en la nube. Finder puede mostrar `한글.txt`, mientras Alfred, la búsqueda en terminal o algunos scripts ven `ㅎㅏㄴㄱㅡㄹ.txt` y no encuentran el archivo.

MoaIMF no trata esto como un script de limpieza de una sola vez. Es una utilidad local que vigila continuamente las carpetas aprobadas por el usuario y corrige problemas de nombre en archivos recién creados o descargados.

## Capturas

Pantalla principal de la app. Mientras vigila carpetas, el icono de la barra de menús cambia por `ㅎ`, `ㅏ`, `ㄴ`, `한`. Al pausar, se detiene en `ㅎ`.

<table>
  <tr>
    <td align="center" width="50%">
      <kbd><img src="../Screenshots/MoaIMF_main_ko.gif" alt="Animación coreana de la barra de menús de MoaIMF" width="100%"></kbd>
    </td>
    <td align="center" width="50%">
      <kbd><img src="../Screenshots/MoaIMF_main_en.png" alt="Pantalla inglesa de la barra de menús de MoaIMF" width="100%"></kbd>
    </td>
  </tr>
</table>

### Carpetas vigiladas

<kbd><img src="../Screenshots/MoaIMF_monitoring_folders_en.png" alt="Ajustes de carpetas vigiladas" width="100%"></kbd>

Los ajustes empiezan con `Downloads` como carpeta predeterminada. Los botones `+` y `-` agregan o eliminan carpetas vigiladas. Cada carpeta puede activarse o desactivarse por separado.

### Excepciones de estabilidad de descargas

<kbd><img src="../Screenshots/MoaIMF_exceptions_en.png" alt="Excepciones de estabilidad de descargas" width="100%"></kbd>

Un archivo en descarga puede no tener todavía su nombre final, o puede seguir cambiando de tamaño y fecha de modificación. MoaIMF incluye reglas bloqueadas para `.crdownload`, `.download`, `.part`, `.partial`, `.tmp` y permite reglas personalizadas.

### Historial reciente

<kbd><img src="../Screenshots/MoaIMF_recent_history_en.png" alt="Historial reciente" width="100%"></kbd>

El historial puede verse por hoy, 7 días, 30 días o todo el tiempo, y filtrarse por renombrados, conflictos, permisos o errores. La búsqueda también compara variantes normalizadas para tratar diferencias NFC/NFD como la misma entrada.

```text
~/Library/Containers/<app bundle identifier>/Data/Library/Application Support/MoaIMF/history.jsonl
```

### Acerca de

<kbd><img src="../Screenshots/MoaIMF_about_en.png" alt="Acerca de MoaIMF" width="100%"></kbd>

La ventana About muestra nombre, versión, descripción breve y copyright. La imagen ilustra cómo jamo descompuestos se combinan en un carácter compuesto, como `ㅎㅏㄴ -> 한`.

## Funciones

- Ver el estado desde la barra de menús, pausar, reanudar y salir
- Usar Downloads como ubicación vigilada predeterminada
- Administrar varias carpetas con `+` y `-`
- Escanear carpetas de forma recursiva
- Acceder solo a carpetas elegidas por el usuario mediante security-scoped bookmarks
- Detectar cambios con FSEvents
- Procesar solo cuando tamaño y fecha de modificación se estabilizan
- No sobrescribir automáticamente si puede haber conflicto
- Guardar historial local de cambios, conflictos, permisos y errores
- Sin servidor externo, cuenta ni telemetría

## Cómo funciona

MoaIMF no cambia el contenido de los archivos. Solo maneja la forma de normalización Unicode de nombres de archivos y carpetas.

El flujo: el usuario elige una carpeta, la app guarda el permiso como bookmark, FSEvents informa cambios, el servicio de escaneo revisa excepciones y estabilidad, calcula el nombre NFC, comprueba conflictos, verifica identidad antes y después del rename, y guarda el resultado.

MoaIMF no fusiona archivos conflictivos ni crea automáticamente nombres como `-1`, `copy` o `복사본`. Los casos que requieren decisión del usuario quedan en historial y notificaciones.

## Uso

1. Abre `MoaIMF.app`; el icono aparece en la barra de menús.
2. Abre `Watched Folder Settings...` y agrega carpetas.
3. Elige `Normalize Existing Items` o `Watch New Items Only`.
4. Usa `Pause Watching` y `Resume Watching`.
5. Usa `Scan All Now` o `Scan Now` para escanear manualmente.
6. Elige idioma en `Language`.
7. Activa `Launch at Login` si quieres que arranque al iniciar sesión.
8. Elige `Quit MoaIMF` para salir sin dejar daemon ni helper.

Los idiomas incluidos son traducciones de IA para comodidad. Informa errores o solicitudes de idiomas mediante `Issues`.

## Instalación y build

MoaIMF actualmente se instala desde código fuente. Todavía no se proporciona un paquete firmado con Developer ID y notarizado por Apple.

```sh
git clone https://github.com/charliehotel/MoaIMF.git
cd MoaIMF
scripts/check.sh
open .build/MoaIMF.app
```

Requisitos: macOS 13 Ventura o posterior, Xcode 16 o Command Line Tools compatibles, Swift 6 toolchain y Git. Para construir solo el bundle:

```sh
scripts/build-app.sh
```

## Datos locales

MoaIMF guarda estado e historial en Application Support dentro del contenedor sandbox de la app macOS.

```text
~/Library/Containers/<app bundle identifier>/Data/Library/Application Support/MoaIMF/
```

Archivos principales: `watched-folders.json`, `stability-rules.json`, `history.jsonl`, `recovery/`. Algunos ajustes también se guardan en `UserDefaults`.

## Seguridad y privacidad

MoaIMF solo cambia nombres. No lee ni modifica contenido, accede solo a carpetas elegidas, no sigue symlinks, no escanea paquetes como `.app` o `.photoslibrary`, verifica conflictos y funciona completamente en local. No hay red, cuenta, analytics ni telemetría.

## Limitaciones

MoaIMF no cambia el almacenamiento de nombres de macOS en todo el sistema, no obliga a todas las apps a guardar en NFC, no resuelve conflictos automáticamente, no reconstruye índices de Spotlight o Alfred, y por ahora se centra en builds desde código fuente.

## Desinstalación

1. Desactiva `Launch at Login`.
2. Elige `Quit MoaIMF`.
3. Elimina `MoaIMF.app`.
4. Para borrar estado local, elimina la carpeta Application Support de MoaIMF dentro del contenedor de la app.

```text
~/Library/Containers/<app bundle identifier>/Data/Library/Application Support/MoaIMF/
```

Esto no revierte a NFD los nombres ya cambiados a NFC.

## Desarrollo

El proyecto usa Swift Package Manager.

```sh
xcrun swift-format lint --strict --recursive Sources Tests Package.swift
swift test
swift build
scripts/build-app.sh
```

- [Especificación v0.1](../docs/superpowers/specs/2026-06-21-moaimf-v0.1-design.md)
- [Plan de implementación v0.1](../docs/superpowers/plans/2026-06-21-moaimf-v0.1.md)
- [Guía de contribución](../CONTRIBUTING.md)
- [Política de seguridad](../SECURITY.md)

## Licencia

MoaIMF se distribuye bajo [MIT License](../LICENSE).
