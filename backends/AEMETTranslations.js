.pragma library

// Archivo generado automáticamente. No editar manualmente.
var catalog = {
    "es": {
        "title": "AEMET",
        "instructions": "Para obtener tu API key:<ol><li>Ve al <b><a href='%1'>Centro de Descargas de AEMET</a></b>.</li><li>Haz clic en <b>Obtener API Key</b>.</li><li>Introduce tu correo electrónico y recibirás la clave en unos minutos.</li><li>Cópiala e introdúcela arriba.</li></ol>",
        "attribution": "Información elaborada por la %1Agencia Estatal de Meteorología%2.",
        "short-attribution": "© AEMET",
        "geonames-attribution": "Búsqueda de ubicaciones por %1GeoNames%2.",
        "ign-attribution": "Geocodificación inversa por %1IGN CartoCiudad%2."
    },
    "en": {
        "title": "AEMET",
        "instructions": "To obtain your API key:<ol><li>Go to the <b><a href='%1'>AEMET Download Center</a></b>.</li><li>Click on <b>Get API Key</b>.</li><li>Enter your email address and you will receive the key in a few minutes.</li><li>Copy it and enter it above.</li></ol>",
        "attribution": "Information provided by the %1State Meteorological Agency (AEMET)%2.",
        "short-attribution": "© AEMET",
        "geonames-attribution": "Location search by %1GeoNames%2.",
        "ign-attribution": "Reverse geocoding by %1IGN CartoCiudad%2."
    }
};

function translate(id, lang) {
    var l = (lang || "en").toLowerCase().substring(0, 2);
    if (!catalog[l]) l = "en";
    var translation = catalog[l][id] || catalog["en"][id] || id;
    return translation;
}
