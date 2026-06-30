import QtQuick 2.6
import "BackendUtils.js" as BackendUtils
import "WeatherTypeDescriptions.js" as WeatherTypeDescriptions
import "AEMETTranslations.js" as Translations
import "AEMETUtils.js" as AEMETUtils

QtObject {
    function providerId() { return "aemet" }
    function providerTitle() { return Translations.translate("title", getLanguage()) }
    function requiresApiKey() { return true }
    function apiKeyInstructions() { return Translations.translate("instructions", getLanguage()).arg("https://opendata.aemet.es/centrodedescargas/inicio") }
    function attributionText() { return Translations.translate("attribution", getLanguage()).arg("<a href='https://www.aemet.es/'>").arg("</a>") }
    function shortAttributionText() { return Translations.translate("short-attribution", getLanguage()) }
    function locationSearchAttributionText() {
        return Translations.translate("ign-attribution", getLanguage()).arg("<a href='https://www.cartociudad.es/'>").arg("</a>")
    }

    function canLoadWeather(weather) {
        return !!weather && (!!weather.locationId || (weather.latitude !== undefined && weather.longitude !== undefined));
    }

    function fetchToken(weatherRequest, apiKey) {
        return AEMETUtils.fetchToken(weatherRequest, apiKey)
    }

    function requestHeaders() { return { "Accept": "application/json", "User-Agent": "Sailfish Weather/1.0 (+https://github.com/juanro49/harbour-weather-backend-aemet)" } }
    function getLanguage() { var locale = Qt.locale().name; return (locale.length >= 2) ? locale.substring(0, 2).toLowerCase() : "en" }

    function getIneCode(weather) {
        if (!weather) return "";
        var id = (weather.id || weather.locationId || "").toString();
        if (/^\d{1,5}$/.test(id)) {
            while (id.length < 5) id = "0" + id;
            return id;
        }
        return AEMETUtils.getIneCode(weather.latitude, weather.longitude) || "";
    }

    function currentWeatherUrl(weather) {
        var ine = getIneCode(weather);
        if (!ine) return "";
        return "https://opendata.aemet.es/opendata/api/prediccion/especifica/municipio/horaria/" + ine + "?api_key=";
    }
    function latestObservationUrl(weather) { return currentWeatherUrl(weather) }
    function forecastUrl(weather, isHourly) {
        var ine = getIneCode(weather);
        if (!ine) return "";
        var type = isHourly ? "horaria/" : "diaria/";
        var url = "https://opendata.aemet.es/opendata/api/prediccion/especifica/municipio/" + type + ine;
        // Change URL periodically to force Events View to refresh.
        // 30 min for hourly, 180 min for daily to match sailfish-weather's maxUpdateInterval.
        var interval = isHourly ? 1800000 : 10800000;
        url += "?t=" + Math.floor(Date.now() / interval);
        url += "&api_key=";
        return url;
    }

    function searchLocationUrl(filter, language) {
        return "https://www.cartociudad.es/geocoder/api/geocoder/candidates?q=" + encodeURIComponent(filter) + "&token=";
    }
    function reverseLocationResponseType() { return "json" }
    function reverseLocationUrl(latitude, longitude, language) {
        return "https://www.cartociudad.es/geocoder/api/geocoder/reverseGeocode?lon=" + longitude + "&lat=" + latitude + "&token=";
    }

    function handleSearchLocationResult(result) {
        if (!result || !Array.isArray(result)) return undefined;
        var locations = [];
        for (var i = 0; i < result.length; i++) {
            var item = result[i];
            if (item.muniCode && item.muniCode.length >= 4) {
                var code = item.muniCode;
                while (code.length < 5) code = "0" + code;
                locations.push({
                    "id": code,
                    "name": item.address || item.muni,
                    "city": item.muni,
                    "country": "España",
                    "state": item.province,
                    "adminArea": item.province,
                    "adminArea2": "",
                    "latitude": item.lat || 0,
                    "longitude": item.lng || 0
                });
            }
        }
        return locations;
    }

    function handleReverseLocationResult(result, latitude, longitude) {
        if (!result || !result.muniCode) return undefined;
        var code = result.muniCode;
        while (code.length < 5) code = "0" + code;
        return {
            "id": code,
            "name": result.nombreMunicio || result.nombre || "Ubicación actual",
            "city": result.nombreMunicio || result.nombre || "",
            "country": "España",
            "state": result.provincia || "",
            "adminArea": result.provincia || "",
            "adminArea2": "",
            "latitude": latitude,
            "longitude": longitude
        };
    }

    function handleCurrentWeatherResult(result) {
        if (!result || !Array.isArray(result) || !result[0] || !result[0].prediccion || !result[0].prediccion.dia) return undefined;

        AEMETUtils.updateDataCache(result, "hourly");
        var prediccion = result[0].prediccion;
        var now = new Date();
        var hStr = (now.getHours() < 10 ? "0" : "") + now.getHours();
        var dStr = now.getFullYear() + "-" + ((now.getMonth() + 1) < 10 ? "0" : "") + (now.getMonth() + 1) + "-" + (now.getDate() < 10 ? "0" : "") + now.getDate();

        var res = { temp: 0, state: "", feels: 0, precip: 0 };
        var found = false;
        var day0 = prediccion.dia[0];

        function findVal(arr, target) {
            if (!arr) return undefined;
            for (var i = 0; i < arr.length; i++) {
                var ah = arr[i].hora || arr[i].periodo;
                if (ah !== undefined && (ah.toString() === target.toString() || (ah.toString().length === 1 && "0" + ah === target))) return arr[i];
            }
            return undefined;
        }

        for (var d = 0; d < prediccion.dia.length; d++) {
            var day = prediccion.dia[d];
            if (day.fecha.substring(0, 10) === dStr) {
                var t = findVal(day.temperatura, hStr);
                if (!t && day.temperatura && day.temperatura.length > 0) t = day.temperatura[0];
                if (t) {
                    res.temp = AEMETUtils.parseAEMETValue(t.value);
                    var targetH = t.hora || t.periodo;
                    var s = findVal(day.estadoCielo, targetH); if (s) { res.state = s.value; res.desc = s.descripcion; }
                    var f = findVal(day.sensTermica, targetH); if (f) res.feels = AEMETUtils.parseAEMETValue(f.value);
                    var p = findVal(day.precipitacion, targetH); if (p) res.precip = AEMETUtils.parseAEMETValue(p.value);
                    found = true; break;
                }
            }
        }

        if (!found) {
            for (var i = 0; i < prediccion.dia.length; i++) {
                if (prediccion.dia[i].fecha.substring(0, 10) >= dStr) {
                    day0 = prediccion.dia[i];
                    break;
                }
            }
            if (day0 && day0.temperatura && day0.temperatura.length > 0) res.temp = AEMETUtils.parseAEMETValue(day0.temperatura[0].value);
        }

        return {
            "timestamp": now,
            "temperature": res.temp,
            "feelsLikeTemperature": res.feels || res.temp,
            "weatherType": AEMETUtils.weatherTypeFromAEMET(res.state),
            "description": res.desc || (day0.estadoCielo && day0.estadoCielo[0] ? day0.estadoCielo[0].descripcion : ""),
            "cloudiness": AEMETUtils.cloudinessFromAEMET(res.state)
        };
    }

    function handleForecastResult(result, hourly, visibleCount, minimumHourlyRange) {
        if (!result || !Array.isArray(result) || !result[0] || !result[0].prediccion) return undefined;

        var type = hourly ? "hourly" : "daily";
        AEMETUtils.updateDataCache(result, type);

        var weatherData = [];
        var prediccion = result[0].prediccion;
        var ine = result[0].id;

        if (hourly) {
            for (var d = 0; d < prediccion.dia.length; d++) {
                var day = prediccion.dia[d];
                var dateStr = day.fecha.substring(0, 10);
                if (!day.temperatura) continue;
                for (var h = 0; h < day.temperatura.length; h++) {
                    var tObj = day.temperatura[h]; var hVal = tObj.hora || tObj.periodo; if (hVal === undefined) continue;
                    var ts = new Date(dateStr + "T" + (hVal < 10 ? "0" : "") + hVal + ":00:00");
                    if (isNaN(ts.getTime())) continue;

                    function getV(arr, target) {
                        if (!arr) return undefined;
                        for (var i = 0; i < arr.length; i++) {
                            var ah = arr[i].hora || arr[i].periodo;
                            if (ah !== undefined && ah.toString() === target.toString()) return arr[i];
                        }
                        return undefined;
                    }
                    var sObj = getV(day.estadoCielo, hVal);
                    weatherData.push({
                        "timestamp": ts,
                        "temperature": AEMETUtils.parseAEMETValue(tObj.value),
                        "weatherType": AEMETUtils.weatherTypeFromAEMET(sObj ? sObj.value : ""),
                        "description": sObj ? sObj.descripcion : "",
                        "cloudiness": AEMETUtils.cloudinessFromAEMET(sObj ? sObj.value : "")
                    });
                }
            }
            var now = Date.now();
            weatherData = weatherData.filter(function(w) { return w.timestamp.getTime() > now - 3600000; });
            weatherData.sort(function(a, b) { return a.timestamp - b.timestamp; });
            return BackendUtils.normalizeHourlyTemperatures(weatherData, visibleCount, minimumHourlyRange, true);
        } else {
            var n = new Date();
            var todayStr = n.getFullYear() + "-" + ((n.getMonth() + 1) < 10 ? "0" : "") + (n.getMonth() + 1) + "-" + (n.getDate() < 10 ? "0" : "") + n.getDate();
            for (var i = 0; i < prediccion.dia.length; i++) {
                var dd = prediccion.dia[i];
                var dateStr = dd.fecha.substring(0, 10);
                if (dateStr < todayStr) continue;

                var maxT = dd.temperatura ? AEMETUtils.parseAEMETValue(dd.temperatura.maxima) : 0;
                var minT = dd.temperatura ? AEMETUtils.parseAEMETValue(dd.temperatura.minima) : 0;
                var sObjArr = dd.estadoCielo || [];
                var st = sObjArr[0] ? sObjArr[0].value : "";
                var maxWind = 0, windD = 0;

                if (dd.viento) {
                    for (var j = 0; j < dd.viento.length; j++) {
                        var v = AEMETUtils.convertWindSpeed(dd.viento[j].velocidad);
                        if (v > maxWind) { maxWind = v; windD = AEMETUtils.parseWindDirection(dd.viento[j].direccion); }
                    }
                }
                if (Array.isArray(dd.rachaMax)) {
                    for (var j = 0; j < dd.rachaMax.length; j++) {
                        var r = AEMETUtils.convertWindSpeed(dd.rachaMax[j].value || dd.rachaMax[j]);
                        if (r > maxWind) maxWind = r;
                    }
                }

                var accum = AEMETUtils.getDailyPrecipitation(ine, dateStr) || 0;

                weatherData.push({
                    "timestamp": new Date(dateStr + "T12:00:00"),
                    "high": Math.floor(maxT),
                    "low": Math.round(minT),
                    "accumulatedPrecipitation": accum,
                    "maximumWindSpeed": maxWind,
                    "windDirection": windD,
                    "weatherType": AEMETUtils.weatherTypeFromAEMET(st),
                    "description": sObjArr[0] ? sObjArr[0].descripcion : "",
                    "cloudiness": AEMETUtils.cloudinessFromAEMET(st)
                });
            }
            return weatherData;
        }
    }

    function handleObservationResult(result) {
        return (result && Array.isArray(result) && result[0] && result[0].nombre) ? result[0].nombre : "";
    }
    function externalUrl(weather) {
        var name = weather.city ? weather.city.toLowerCase().replace(/ /g, "-") : "municipio";
        return "https://www.aemet.es/es/eltiempo/prediccion/municipios/" + AEMETUtils.removeAccents(name) + "-id" + (getIneCode(weather) || "");
    }
    function providerImage() { return "image://theme/graphic-aemet-large?" }
    function smallProviderImage() { return "image://theme/graphic-aemet-small?" }
}
