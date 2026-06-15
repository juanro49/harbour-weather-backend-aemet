# AEMET Weather Backend for Sailfish OS

Este es un plugin externo para la aplicación nativa **Sailfish Weather** que permite utilizar los servicios meteorológicos de la **AEMET (Agencia Estatal de Meteorología)**.

## ✨ Características

- **Datos Oficiales**: Información meteorológica directamente de la fuente oficial en España (AEMET OpenData).
- **Geocodificación Inteligente**: Traduce automáticamente tus coordenadas a códigos de municipio (INE) mediante la API oficial de **IGN CartoCiudad**.
- **Pronóstico Detallado**: Pronóstico hora a hora para las próximas 48 horas y diario para 7 días.
- **Integración Nativa**: Se integra perfectamente en la aplicación nativa de Clima de Sailfish OS.
- **Ligero**: No requiere aplicaciones adicionales, solo el plugin.

## 🚀 Instalación

### Vía RPM
1. Busca **AEMET Weather Backend** en Storeman o instálalo directamente desde la web de [OpenRepos](https://openrepos.net/content/juanro49/aemet-weather-backend).
2. Si has descargado el rpm manualmente, instálalo usando la terminal:
   ```bash
   devel-su pkcon install-local harbour-weather-backend-aemet-*.rpm
   ```
3. Reinicia la aplicación **Clima**.

## 🔑 Configuración

Para utilizar este backend, necesitas una API Key gratuita de AEMET OpenData:

1. Ve al [Centro de Descargas de AEMET](https://opendata.aemet.es/centrodedescargas/inicio).
2. Haz clic en **Obtener API Key**.
3. Introduce tu correo electrónico y recibirás la clave en unos minutos.
4. En tu dispositivo Sailfish OS, ve a **Configuración > Aplicaciones > Clima**.
5. Selecciona **AEMET** como proveedor e introduce tu API Key.

## 🛠 Requisitos

- Sailfish OS con la aplicación nativa de Clima instalada.
- `sailfish-components-weather-qt5` versión 1.3.2 o superior.

## 🛠 Desarrollo y Compilación

Si deseas compilar el paquete por tu cuenta o contribuir al desarrollo, necesitas el [Sailfish SDK](https://docs.sailfishos.org/Tools/Sailfish_SDK/).

1. Clona el repositorio:
   ```bash
   git clone https://github.com/juanro49/harbour-weather-backend-aemet.git
   cd harbour-weather-backend-aemet
   ```
2. Configura el objetivo de compilación (la versión exacta dependerá de tus targets instalados, puedes verlos con `sfdk tools list`):
   ```bash
   # Ejemplo para arquitectura de 64 bits (aarch64)
   sfdk config target=SailfishOS-5.0.0.62-aarch64
   ```
3. Genera el paquete RPM:
   ```bash
   sfdk build
   ```
   *Nota: El proceso de construcción generará automáticamente el diccionario de traducciones `backends/AEMETTranslations.js` a partir de los archivos `.ts`.*

4. (Opcional) Firmar el paquete manualmente:
   ```bash
   rpmsign --addsign --define "_gpg_name <TU_ID_DE_CLAVE>" RPMS/*.rpm
   ```

## 🙏 Créditos y Atribuciones

- Datos meteorológicos elaborados por la **Agencia Estatal de Meteorología (AEMET)**.
- Geocodificación inversa proporcionada por **IGN CartoCiudad**.
- Búsqueda de ubicaciones por **GeoNames**.
- Basado en la estructura de backends de la aplicación [Sailfish Weather](https://github.com/sailfishos/sailfish-weather).

## 📄 Licencia

Este proyecto está bajo la licencia **BSD 3-Clause**. Consulta el archivo `LICENSE` para más detalles.
