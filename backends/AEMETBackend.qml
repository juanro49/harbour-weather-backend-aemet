import QtQuick 2.6
import "BackendUtils.js" as BackendUtils
import "GeoNames.js" as GeoNames
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
        return Translations.translate("geonames-attribution", getLanguage()).arg("<a href='https://www.geonames.org/'>").arg("</a>") + "<br/>" +
               Translations.translate("ign-attribution", getLanguage()).arg("<a href='https://www.cartociudad.es/'>").arg("</a>")
    }
    function maxPrecision() { return 5 }

    function canLoadWeather(weather) {
        if (!weather || weather.latitude === undefined || weather.longitude === undefined) return false;
        var lat = weather.latitude; var lon = weather.longitude;
        return (lat >= 27.0 && lat <= 44.0 && lon >= -19.0 && lon <= 5.0);
    }

    function fetchToken(weatherRequest, apiKey) { weatherRequest.token = apiKey || ""; return true; }
    function requestHeaders() { return { "Accept": "application/json", "User-Agent": "Sailfish Weather/1.0 (+https://github.com/juanro49/harbour-weather-backend-aemet)" } }
    function getLanguage() { var locale = Qt.locale().name; return (locale.length >= 2) ? locale.substring(0, 2).toLowerCase() : "en" }

    function getIneCode(weather) {
        if (weather.id && /^\d{5}$/.test(weather.id)) return weather.id;
        return AEMETUtils.getIneCode(weather.latitude, weather.longitude);
    }

    function currentWeatherUrl(weather) {
        var ine = getIneCode(weather);
        return ine ? "https://opendata.aemet.es/opendata/api/prediccion/especifica/municipio/horaria/" + ine + "?api_key=" : "";
    }
    function latestObservationUrl(weather) { return currentWeatherUrl(weather) }
    function forecastUrl(weather, isHourly) {
        var ine = getIneCode(weather); if (!ine) return "";
        var type = isHourly ? "horaria/" : "diaria/";
        return "https://opendata.aemet.es/opendata/api/prediccion/especifica/municipio/" + type + ine + "?api_key="
    }

    function searchLocationUrl(filter, language) {
        var url = GeoNames.searchLocationUrl(filter, language).replace(/&token=$/, "");
        if (url.indexOf("country=ES") === -1) url += "&country=ES";
        return url + "&token=";
    }
    function reverseLocationResponseType() { return "json" }
    function reverseLocationUrl(latitude, longitude, language) { return GeoNames.reverseLocationUrl(latitude, longitude, language).replace(/&token=$/, "") + "&token="; }

    function handleCurrentWeatherResult(result) {
        var data = AEMETUtils.fetchAEMETData(result, "hourly");
        if (!data || !data[0] || !data[0].prediccion || !data[0].prediccion.dia) return undefined;

        var prediccion = data[0].prediccion;
        var ine = data[0].id;
        var now = new Date();
        var hStr = (now.getHours() < 10 ? "0" : "") + now.getHours();
        var dStr = now.getFullYear() + "-" + ((now.getMonth() + 1) < 10 ? "0" : "") + (now.getMonth() + 1) + "-" + (now.getDate() < 10 ? "0" : "") + now.getDate();

        var res = { temp: 0, state: "", feels: 0, hum: 0, precip: 0, prob: 0, windVel: 0, windDir: 0, desc: "" };
        var found = false;

        for (var d = 0; d < prediccion.dia.length; d++) {
            var day = prediccion.dia[d];
            if (day.fecha.substring(0, 10) === dStr || d === 0) {
                function findVal(arr, target) {
                    if (!arr) return undefined;
                    for (var i = 0; i < arr.length; i++) {
                        var ah = arr[i].hora || arr[i].periodo;
                        if (ah === target || (ah && ah.length === 1 && "0" + ah === target)) return arr[i];
                    }
                    return undefined;
                }
                var t = findVal(day.temperatura, hStr);
                if (t) {
                    res.temp = AEMETUtils.parseAEMETValue(t.value);
                    var s = findVal(day.estadoCielo, hStr); if (s) { res.state = s.value; res.desc = s.descripcion; }
                    var f = findVal(day.sensTermica, hStr); if (f) res.feels = AEMETUtils.parseAEMETValue(f.value);

                    var hObj = findVal(day.humedadRelativa, hStr); if (hObj) res.hum = AEMETUtils.parseAEMETValue(hObj.value);
                    var pObj = findVal(day.precipitacion, hStr); if (pObj) res.precip = AEMETUtils.parseAEMETValue(pObj.value);
                    var prObj = findVal(day.probPrecipitacion, hStr); if (prObj) res.prob = AEMETUtils.parseAEMETValue(prObj.value);

                    if (day.vientoAndRachaMax) {
                        for (var k = 0; k < day.vientoAndRachaMax.length; k++) {
                            var vObj = day.vientoAndRachaMax[k];
                            var vh = vObj.hora || vObj.periodo;
                            if ((vh === hStr || (vh && vh.length === 1 && "0" + vh === hStr)) && vObj.velocidad) {
                                res.windVel = AEMETUtils.parseAEMETValue(vObj.velocidad);
                                res.windDir = AEMETUtils.parseWindDirection(vObj.direccion);
                                break;
                            }
                        }
                    }
                    found = true; break;
                }
            }
        }

        if (!found && prediccion.dia[0].temperatura && prediccion.dia[0].temperatura.length > 0) res.temp = AEMETUtils.parseAEMETValue(prediccion.dia[0].temperatura[0].value);

        var relTemp = 0.5;
        var day0 = prediccion.dia[0];
        if (day0.temperatura && day0.temperatura.maxima !== undefined) {
            var tMax = parseFloat(day0.temperatura.maxima); var tMin = parseFloat(day0.temperatura.minima);
            if (tMax - tMin > 0) relTemp = (res.temp - tMin) / (tMax - tMin);
        }

        var accum = AEMETUtils.getDailyPrecipitation(ine, dStr) || res.precip;

        return {
            "timestamp": now, "temperature": res.temp, "feelsLikeTemperature": res.feels || res.temp,
            "description": res.desc || (day0.estadoCielo && day0.estadoCielo[0] ? day0.estadoCielo[0].descripcion : ""),
            "weatherType": AEMETUtils.weatherTypeFromAEMET(res.state), "cloudiness": AEMETUtils.cloudinessFromAEMET(res.state),
            "precipitation": res.precip, "accumulatedPrecipitation": accum, "precipitationProbability": res.prob,
            "windSpeed": Math.round(res.windVel), "windDirection": res.windDir,
            "humidity": res.hum, "pressure": 0, "relativeTemperature": Math.max(0, Math.min(1, relTemp))
        };
    }

    function handleForecastResult(result, hourly, visibleCount, minimumHourlyRange) {
        var data = AEMETUtils.fetchAEMETData(result, hourly ? "hourly" : "daily");
        if (!data || !data[0] || !data[0].prediccion) return undefined;
        var weatherData = [];
        var prediccion = data[0].prediccion;
        var ine = data[0].id;

        if (hourly) {
            for (var d = 0; d < prediccion.dia.length; d++) {
                var day = prediccion.dia[d];
                var dateStr = day.fecha.substring(0, 10);
                if (!day.temperatura) continue;
                for (var h = 0; h < day.temperatura.length; h++) {
                    var tObj = day.temperatura[h]; var hVal = tObj.hora || tObj.periodo; if (hVal === undefined) continue;
                    var hs = hVal.toString(); if (hs.length === 1) hs = "0" + hs;
                    var ts = new Date(dateStr + "T" + hs + ":00:00"); if (isNaN(ts.getTime())) continue;

                    var st = "", pr = 0, prob = 0, wv = 0, wd = 0, fs = 0, hm = 0;
                    function getV(arr, target) {
                        if (!arr) return undefined;
                        for (var i = 0; i < arr.length; i++) {
                            var ah = arr[i].hora || arr[i].periodo;
                            if (ah !== undefined && ah.toString() === target.toString()) return arr[i];
                        }
                        return undefined;
                    }
                    var sObj = getV(day.estadoCielo, hVal); if (sObj) st = sObj.value;
                    var pObj = getV(day.precipitacion, hVal); if (pObj) pr = AEMETUtils.parseAEMETValue(pObj.value);
                    var prObj = getV(day.probPrecipitacion, hVal); if (prObj) prob = AEMETUtils.parseAEMETValue(prObj.value);
                    var fObj = getV(day.sensTermica, hVal); if (fObj) fs = AEMETUtils.parseAEMETValue(fObj.value);
                    var hObj = getV(day.humedadRelativa, hVal); if (hObj) hm = AEMETUtils.parseAEMETValue(hObj.value);
                    if (day.vientoAndRachaMax) {
                        for (var k = 0; k < day.vientoAndRachaMax.length; k++) {
                            var vObj = day.vientoAndRachaMax[k]; var vh = vObj.hora || vObj.periodo;
                            if (vh !== undefined && vh.toString() === hVal.toString() && vObj.velocidad) {
                                wv = AEMETUtils.parseAEMETValue(vObj.velocidad); wd = AEMETUtils.parseWindDirection(vObj.direccion); break;
                            }
                        }
                    }
                    weatherData.push({
                        "timestamp": ts, "temperature": AEMETUtils.parseAEMETValue(tObj.value), "feelsLikeTemperature": fs || AEMETUtils.parseAEMETValue(tObj.value),
                        "weatherType": AEMETUtils.weatherTypeFromAEMET(st), "cloudiness": AEMETUtils.cloudinessFromAEMET(st),
                        "description": "", "precipitation": pr, "precipitationProbability": prob, "windSpeed": Math.round(wv), "windDirection": wd, "humidity": hm
                    });
                }
            }
            var now = Date.now();
            weatherData = weatherData.filter(function(w) { return w.timestamp.getTime() > now - 3600000; });
            weatherData.sort(function(a, b) { return a.timestamp - b.timestamp; });
            return BackendUtils.normalizeHourlyTemperatures(weatherData, visibleCount, minimumHourlyRange, true);
        } else {
            for (var i = 0; i < prediccion.dia.length; i++) {
                var dd = prediccion.dia[i];
                var dateStr = dd.fecha.substring(0, 10);
                var date = new Date(dateStr + "T12:00:00");
                var maxT = dd.temperatura ? AEMETUtils.parseAEMETValue(dd.temperatura.maxima) : 0;
                var minT = dd.temperatura ? AEMETUtils.parseAEMETValue(dd.temperatura.minima) : 0;
                var st = dd.estadoCielo && dd.estadoCielo[0] ? dd.estadoCielo[0].value : "";
                var prob = 0;
                if (dd.probPrecipitacion) {
                    for (var j = 0; j < dd.probPrecipitacion.length; j++) {
                        if (dd.probPrecipitacion[j].periodo === "00-24" || dd.probPrecipitacion[j].periodo === "") {
                            prob = dd.probPrecipitacion[j].value; break;
                        }
                    }
                }
                var maxWind = 0, windD = 0;
                if (dd.viento) {
                    for (var j = 0; j < dd.viento.length; j++) {
                        var v = AEMETUtils.parseAEMETValue(dd.viento[j].velocidad);
                        if (v > maxWind) { maxWind = v; windD = AEMETUtils.parseWindDirection(dd.viento[j].direccion); }
                    }
                }
                if (dd.rachaMax) {
                    for (var j = 0; j < dd.rachaMax.length; j++) {
                        var r = AEMETUtils.parseAEMETValue(dd.rachaMax[j].value);
                        if (r > maxWind) maxWind = r;
                    }
                }

                var accum = AEMETUtils.getDailyPrecipitation(ine, dateStr);
                // If it's 0 or undefined but sky state is rainy, set at least 0.1mm for visual consistency
                if ((!accum || accum === 0) && (parseInt(st) >= 20 && parseInt(st) <= 79)) accum = 0.1;

                weatherData.push({
                    "timestamp": date, "high": Math.floor(maxT), "low": Math.round(minT),
                    "weatherType": AEMETUtils.weatherTypeFromAEMET(st), "description": dd.estadoCielo && dd.estadoCielo[0] ? dd.estadoCielo[0].descripcion : "",
                    "cloudiness": AEMETUtils.cloudinessFromAEMET(st), "precipitationProbability": AEMETUtils.parseAEMETValue(prob),
                    "accumulatedPrecipitation": accum || 0, "maximumWindSpeed": Math.round(maxWind), "windDirection": windD
                });
            }
            return weatherData;
        }
    }

    function handleSearchLocationResult(result) { return GeoNames.handleSearchLocationResult(result) }
    function handleReverseLocationResult(result, latitude, longitude) { return GeoNames.handleReverseLocationResult(result, latitude, longitude) }
    function handleObservationResult(result) {
        var data = AEMETUtils.fetchAEMETData(result, "hourly");
        return (data && data[0] && data[0].nombre) ? data[0].nombre : "";
    }
    function externalUrl(weather) {
        var ine = getIneCode(weather); if (!ine) return "https://www.aemet.es/";
        var name = weather.city ? weather.city.toLowerCase().replace(/ /g, "-") : "municipio";
        return "https://www.aemet.es/es/eltiempo/prediccion/municipios/" + AEMETUtils.removeAccents(name) + "-id" + ine;
    }
    function providerImage() { return "image://theme/graphic-aemet-large?" }
    function smallProviderImage() { return "image://theme/graphic-aemet-small?" }
}
