.pragma library

var USER_AGENT = "Sailfish Weather/1.0 (+https://github.com/juanro49/harbour-weather-backend-aemet)";
var urlCache = {};
var dataCache = {};
var pendingRequests = [];
var inFlight = {};
var ineCache = {};

function fetchToken(request, apiKey) {
    if (!request || !request.source) return false;
    if (request.source.indexOf("/sh/") !== -1) {
        request.token = "";
        return true;
    }
    if (request.source.indexOf("opendata.aemet.es") === -1) {
        request.token = apiKey || "";
        return true;
    }
    if (!apiKey) {
        request.token = "";
        return true;
    }

    var sourceUrl = request.source;
    if (urlCache[sourceUrl]) {
        var directUrl = urlCache[sourceUrl];
        if (directUrl.indexOf("/sh/") !== -1) {
            request.source = directUrl;
            request.token = "";
        } else {
            request.token = apiKey;
        }
        return true;
    }
    if (!inFlight[sourceUrl]) {
        inFlight[sourceUrl] = true;
        var metadataUrl = sourceUrl;
        metadataUrl += (metadataUrl.indexOf("?") === -1 ? "?" : "&") + "api_key=" + apiKey;

        var xhr = new XMLHttpRequest();
        xhr.open("GET", metadataUrl, true);
        xhr.setRequestHeader("User-Agent", USER_AGENT);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                var directUrl = undefined;
                if (xhr.status === 200) {
                    try {
                        var res = JSON.parse(xhr.responseText);
                        if (res && res.datos) {
                            directUrl = res.datos;
                            urlCache[sourceUrl] = directUrl;
                        }
                    } catch (e) {}
                }
                finalizePending(sourceUrl, directUrl, apiKey, xhr.status);
                delete inFlight[sourceUrl];
            }
        };
        xhr.send();
    }
    pendingRequests.push(request);
    return false;
}

function finalizePending(sourceUrl, directUrl, apiKey, status) {
    var stillPending = [];
    for (var i = 0; i < pendingRequests.length; i++) {
        var req = pendingRequests[i];
        if (req && req.source === sourceUrl) {
            if (directUrl) {
                if (directUrl.indexOf("/sh/") !== -1) {
                    req.source = directUrl;
                    req.token = "";
                } else {
                    req.token = apiKey;
                }
                if (typeof req.sendRequest === "function") {
                    req.sendRequest();
                }
            } else {
                if (typeof req.status !== "undefined") {
                    req.status = (status === 401) ? 4 : 3;
                }
            }
        } else {
            stillPending.push(req);
        }
    }
    pendingRequests = stillPending;
}

function updateDataCache(result, type) {
    if (!result || !Array.isArray(result) || !result[0]) return;
    var ine = result[0].id;
    if (ine) {
        dataCache[ine + "_" + type] = {
            data: result,
            timestamp: Date.now()
        };
    }
}

function getDailyPrecipitation(ine, dateStr) {
    var target = dateStr.substring(0, 10);
    var entry = dataCache[ine + "_hourly"];
    if (entry && entry.data && entry.data[0].prediccion.dia) {
        var days = entry.data[0].prediccion.dia;
        for (var i = 0; i < days.length; i++) {
            if (days[i].fecha.substring(0, 10) === target) {
                var total = 0;
                var precips = days[i].precipitacion;
                if (precips) {
                    for (var j = 0; j < precips.length; j++) total += parseAEMETValue(precips[j].value);
                    return total;
                }
            }
        }
    }
    return undefined;
}

function getIneCode(latitude, longitude) {
    if (latitude === undefined || longitude === undefined) return undefined;
    var key = latitude.toFixed(2) + "," + longitude.toFixed(2);
    if (ineCache[key]) return ineCache[key];
    var url = "https://www.cartociudad.es/geocoder/api/geocoder/reverseGeocode?lon=" + longitude + "&lat=" + latitude;
    var xhr = new XMLHttpRequest();
    xhr.open("GET", url, true);
    xhr.setRequestHeader("User-Agent", USER_AGENT);
    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
            try {
                var res = JSON.parse(xhr.responseText);
                if (res && res.muniCode) ineCache[key] = res.muniCode;
            } catch (e) {}
        }
    };
    xhr.send();
    return undefined;
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

function convertWindSpeed(kmh) {
    return Math.round(parseAEMETValue(kmh) / 3.6);
}

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
