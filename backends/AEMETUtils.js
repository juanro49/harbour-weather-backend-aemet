.pragma library

var ineCache = {};
var dataCache = {};
var CACHE_DURATION = 3600000; // 1 hour in ms
var USER_AGENT = "Sailfish Weather/1.0 (+https://github.com/juanro49/harbour-weather-backend-aemet)";

/**
 * Removes accents from a string (Qt 5.6 compatible)
 */
function removeAccents(str) {
    if (!str) return "";
    var accents = 'ÀÁÂÃÄÅàáâãäåÒÓÔÕÕÖØòóôõöøÈÉÊËèéêëðÇçÐÌÍÎÏìíîïÙÚÛÜùúûüÑñŠšŸÿýŽž';
    var accentsOut = "AAAAAAaaaaaaOOOOOOOooooooEEEEeeeeecCcDIIIIiiiiUUUUuuuuNnSsYyyZz";
    var s = str.split('');
    for (var i = 0; i < s.length; i++) {
        var x = accents.indexOf(s[i]);
        if (x !== -1) s[i] = accentsOut[x];
    }
    return s.join('');
}

function getIneCode(latitude, longitude) {
    var key = latitude.toFixed(4) + "," + longitude.toFixed(4);
    var now = Date.now();
    if (ineCache[key] && (now - ineCache[key].timestamp < CACHE_DURATION)) return ineCache[key].code;

    var url = "https://www.cartociudad.es/geocoder/api/geocoder/reverseGeocode?lon=" + longitude + "&lat=" + latitude;
    var xhr = new XMLHttpRequest();
    xhr.open("GET", url, false);
    xhr.setRequestHeader("User-Agent", USER_AGENT);
    try {
        xhr.send();
        if (xhr.status === 200) {
            var res = JSON.parse(xhr.responseText);
            if (res && res.muniCode) {
                ineCache[key] = { code: res.muniCode, timestamp: now };
                return res.muniCode;
            }
        }
    } catch (e) { console.warn("AEMET: Error fetching INE code: " + e); }
    return undefined;
}

function fetchAEMETData(metadataResult, type) {
    if (!metadataResult) return undefined;
    if (Array.isArray(metadataResult)) return metadataResult;
    if (!metadataResult.datos) return undefined;

    var url = metadataResult.datos;
    var now = Date.now();
    if (dataCache[url] && (now - dataCache[url].timestamp < CACHE_DURATION)) return dataCache[url].data;

    var xhr = new XMLHttpRequest();
    xhr.open("GET", url, false);
    xhr.setRequestHeader("User-Agent", USER_AGENT);
    try {
        xhr.send();
        if (xhr.status === 200) {
            var data = JSON.parse(xhr.responseText);
            dataCache[url] = {
                data: data,
                timestamp: now,
                type: type,
                ine: (data && data[0]) ? data[0].id : undefined
            };
            return data;
        }
    } catch (e) { console.warn("AEMET: Error fetching data: " + e); }
    return undefined;
}

function getDailyPrecipitation(ine, dateStr) {
    var total = 0;
    var found = false;
    var target = dateStr.substring(0, 10);
    for (var key in dataCache) {
        var entry = dataCache[key];
        if (entry.type === "hourly" && entry.ine === ine) {
            var days = entry.data[0].prediccion.dia;
            for (var i = 0; i < days.length; i++) {
                if (days[i].fecha.substring(0, 10) === target) {
                    var precips = days[i].precipitacion;
                    if (precips) {
                        for (var j = 0; j < precips.length; j++) {
                            total += parseAEMETValue(precips[j].value);
                        }
                        found = true;
                    }
                }
            }
        }
        if (found) break;
    }
    if (found) console.log("AEMET: Rain sum for " + target + ": " + total.toFixed(1) + "mm");
    return found ? total : undefined;
}

function weatherTypeFromAEMET(code) {
    if (!code) return "d300";
    if (Array.isArray(code)) code = code[0];
    var isNight = code.indexOf("n") !== -1;
    var baseCode = code.replace("n", "");
    var prefix = isNight ? "n" : "d";
    switch (baseCode) {
        case "11": case "51": return prefix + "000";
        case "12": case "13": case "17": case "52": case "53": case "54": return prefix + "200";
        case "14": case "15": case "16": return prefix + "300";
        case "23": case "24": case "25": case "26": case "43": case "44": case "45": case "46": case "61": case "62": case "63": case "64": return prefix + "430";
        case "33": case "34": case "35": case "36": case "71": case "72": case "73": case "74": return prefix + "312";
        case "81": case "82": return prefix + "600";
        default: return prefix + "300";
    }
}

function cloudinessFromAEMET(code) {
    if (!code) return 50;
    if (Array.isArray(code)) code = code[0];
    var baseCode = code.replace("n", "");
    switch (baseCode) {
        case "11": return 0;
        case "12": return 25;
        case "13": return 50;
        case "17": return 30;
        case "14": return 75;
        case "15": return 90;
        case "16": return 100;
        default:
            var c = parseInt(baseCode);
            if (c >= 20 && c <= 79) return 100;
            return 50;
    }
}

function parseAEMETValue(val) {
    if (val === undefined || val === null || val === "") return 0;
    if (Array.isArray(val)) val = val[0];
    if (typeof val === "string") {
        if (val === "Ip" || val === "T") return 0.1;
        return parseFloat(val.replace(",", ".")) || 0;
    }
    return parseFloat(val) || 0;
}

function parseWindDirection(dir) {
    if (dir === undefined || dir === null) return 0;
    if (Array.isArray(dir)) dir = dir[0];
    var directions = { "N": 0, "NE": 45, "E": 90, "SE": 135, "S": 180, "SO": 225, "O": 270, "NO": 315, "C": 0 };
    return (directions[dir] !== undefined) ? directions[dir] : 0;
}
