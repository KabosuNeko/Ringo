#include "WeatherController.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QFile>
#include <QDir>
#include <QStandardPaths>
#include <QUrl>
#include <QDebug>

WeatherController::WeatherController(QObject *parent) : QObject(parent) {
    m_timer.setSingleShot(false);
    connect(&m_timer, &QTimer::timeout, this, &WeatherController::onTimerTriggered);
    m_timer.setInterval(m_refreshInterval);
    loadCache();
}

void WeatherController::setWeatherLocation(const QString &v) {
    if (m_weatherLocation == v) return;
    m_weatherLocation = v;
    emit weatherLocationChanged();
}
void WeatherController::setWeatherUnits(const QString &v) {
    if (m_weatherUnits == v) return;
    m_weatherUnits = v;
    emit weatherUnitsChanged();
}
void WeatherController::setRefreshInterval(int v) {
    if (m_refreshInterval == v) return;
    m_refreshInterval = v;
    emit refreshIntervalChanged();
    m_timer.setInterval(m_refreshInterval);
    if (m_active && m_refreshInterval > 0) m_timer.start();
    else m_timer.stop();
}

void WeatherController::setActive(bool v) {
    if (m_active == v) return;
    m_active = v;
    emit activeChanged();
    if (m_active && m_refreshInterval > 0) m_timer.start();
    else m_timer.stop();
}

void WeatherController::setLoading(bool v) { if (m_loading==v) return; m_loading=v; emit loadingChanged(); }
void WeatherController::setErrorMessage(const QString &v) { if (m_errorMessage==v) return; m_errorMessage=v; emit errorMessageChanged(); }

QVariantMap WeatherController::iconForCode(int code) const {
    QVariantMap m;
    if (code == 113) { m["glyph"]=QStringLiteral("\ue30d"); m["color"]=QStringLiteral("#f4c542"); return m; }
    if (code==116 || code==119 || code==122) { m["glyph"]=QStringLiteral("\ue312"); m["color"]=QStringLiteral("#9aa0a6"); return m; }
    const QList<int> rain{176,263,266,293,296,299,302,305,308,311,314,317,320,353,356,359};
    if (rain.contains(code)) { m["glyph"]=QStringLiteral("\ue318"); m["color"]=QStringLiteral("#4a9de8"); return m; }
    const QList<int> thunder{200,386,389,392,395};
    if (thunder.contains(code)) { m["glyph"]=QStringLiteral("\ue31d"); m["color"]=QStringLiteral("#e8b84a"); return m; }
    const QList<int> snow{227,230,323,326,329,332,335,338,350,368,371,374,377};
    if (snow.contains(code)) { m["glyph"]=QStringLiteral("\ue31a"); m["color"]=QStringLiteral("#d8e8f4"); return m; }
    const QList<int> fog{143,248,260};
    if (fog.contains(code)) { m["glyph"]=QStringLiteral("\ue313"); m["color"]=QStringLiteral("#8a8a8a"); return m; }
    m["glyph"]=QStringLiteral("\ue312"); m["color"]=QStringLiteral("#9aa0a6"); return m;
}

QString WeatherController::cachePath() const {
    QString home = qEnvironmentVariable("HOME");
    if (home.isEmpty()) home = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    return home + QStringLiteral("/.cache/ringo/weather.json");
}

void WeatherController::loadCache() {
    QFile f(cachePath());
    if (!f.open(QIODevice::ReadOnly)) return;
    QByteArray data = f.readAll();
    if (!data.isEmpty()) parseAndApply(data);
}

void WeatherController::saveCache(const QByteArray &data) {
    QString p = cachePath();
    QDir().mkpath(QFileInfo(p).absolutePath());
    QFile f(p);
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) f.write(data);
}

void WeatherController::refresh() {
    if (m_loading && m_reply) return;
    if (m_weatherLocation.trimmed().isEmpty()) { setErrorMessage(QStringLiteral("No location set")); return; }
    setLoading(true);
    setErrorMessage(QString());
    QString urlStr = QStringLiteral("https://wttr.in/") + QUrl::toPercentEncoding(m_weatherLocation) + QStringLiteral("?format=j1");
    QNetworkRequest req{QUrl(urlStr)};
    req.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("ringo-shell/1.0"));
    req.setTransferTimeout(15000);
    if (m_reply) { m_reply->abort(); m_reply->deleteLater(); }
    m_reply = m_nam.get(req);
    connect(m_reply, &QNetworkReply::finished, this, &WeatherController::onReplyFinished);
    // A manual refresh never disturbs the polling timer.
}

void WeatherController::onReplyFinished() {
    auto *reply = qobject_cast<QNetworkReply*>(sender());
    if (!reply) return;
    reply->deleteLater();
    if (reply != m_reply) return;
    m_reply = nullptr;
    setLoading(false);
    if (reply->error() != QNetworkReply::NoError) { setErrorMessage(QStringLiteral("Weather fetch failed.")); return; }
    QByteArray data = reply->readAll();
    if (data.isEmpty()) { setErrorMessage(QStringLiteral("Weather fetch failed.")); return; }
    saveCache(data);
    parseAndApply(data);
}

void WeatherController::onTimerTriggered() { refresh(); }

void WeatherController::parseAndApply(const QByteArray &data) {
    QJsonParseError err;
    QJsonDocument doc = QJsonDocument::fromJson(data, &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) { setErrorMessage(QStringLiteral("Weather parse failed")); return; }
    QJsonObject root = doc.object();
    QJsonArray currentArr = root.value(QStringLiteral("current_condition")).toArray();
    QJsonArray weatherArr = root.value(QStringLiteral("weather")).toArray();
    if (currentArr.isEmpty() || weatherArr.isEmpty()) { setErrorMessage(QStringLiteral("Weather parse failed")); return; }
    QJsonObject current = currentArr[0].toObject();
    QJsonObject today = weatherArr[0].toObject();
    bool isMetric = (m_weatherUnits == QStringLiteral("metric"));
    auto setD = [&](double &field, double v, void (WeatherController::*sig)()) {
        if (!qFuzzyCompare(field+1, v+1)) { field=v; emit (this->*sig)(); }
    };
    auto setI = [&](int &field, int v, void (WeatherController::*sig)()) {
        if (field!=v) { field=v; emit (this->*sig)(); }
    };
    auto setS = [&](QString &field, const QString &v, void (WeatherController::*sig)()) {
        if (field!=v) { field=v; emit (this->*sig)(); }
    };
    double temp = isMetric ? current.value(QStringLiteral("temp_C")).toString().toDouble() : current.value(QStringLiteral("temp_F")).toString().toDouble();
    double feels = isMetric ? current.value(QStringLiteral("FeelsLikeC")).toString().toDouble() : current.value(QStringLiteral("FeelsLikeF")).toString().toDouble();
    int hum = current.value(QStringLiteral("humidity")).toString().toInt();
    double wind = isMetric ? current.value(QStringLiteral("windspeedKmph")).toString().toDouble() : current.value(QStringLiteral("windspeedMiles")).toString().toDouble();
    QString cond = current.value(QStringLiteral("weatherDesc")).toArray().first().toObject().value(QStringLiteral("value")).toString();
    // wttr.in field name, consumed only by iconForCode() below.
    QString code = current.value(QStringLiteral("weatherCode")).toString();
    QVariantMap iconData = iconForCode(code.toInt());
    QString glyph = iconData.value(QStringLiteral("glyph")).toString();
    QString color = iconData.value(QStringLiteral("color")).toString();
    QString sunrise, sunset;
    QJsonArray astro = today.value(QStringLiteral("astronomy")).toArray();
    if (!astro.isEmpty()) { QJsonObject a = astro[0].toObject(); sunrise = a.value(QStringLiteral("sunrise")).toString(); sunset = a.value(QStringLiteral("sunset")).toString(); }

    setD(m_temp, temp, &WeatherController::tempChanged);
    setD(m_feelsLike, feels, &WeatherController::feelsLikeChanged);
    setI(m_humidity, hum, &WeatherController::humidityChanged);
    setD(m_windSpeed, wind, &WeatherController::windSpeedChanged);
    setS(m_condition, cond, &WeatherController::conditionChanged);
    setS(m_iconGlyph, glyph, &WeatherController::iconGlyphChanged);
    setS(m_iconColor, color, &WeatherController::iconColorChanged);
    setS(m_sunrise, sunrise, &WeatherController::sunriseChanged);
    setS(m_sunset, sunset, &WeatherController::sunsetChanged);

    // The night light follows the same location as the weather widget.
    QJsonArray areas = root.value(QStringLiteral("nearest_area")).toArray();
    if (!areas.isEmpty()) {
        QJsonObject area = areas[0].toObject();
        double lat = area.value(QStringLiteral("latitude")).toString().toDouble();
        double lon = area.value(QStringLiteral("longitude")).toString().toDouble();
        const bool changed = !qFuzzyCompare(m_latitude + 1.0, lat + 1.0)
            || !qFuzzyCompare(m_longitude + 1.0, lon + 1.0);
        m_latitude = lat;
        m_longitude = lon;
        if (changed) emit coordinatesChanged();
    }

    QVariantList forecast;
    int n = qMin(3, weatherArr.size());
    for (int i=0;i<n;i++) {
        QJsonObject day = weatherArr[i].toObject();
        QString date = day.value(QStringLiteral("date")).toString();
        double maxT = isMetric ? day.value(QStringLiteral("maxtempC")).toString().toDouble() : day.value(QStringLiteral("maxtempF")).toString().toDouble();
        double minT = isMetric ? day.value(QStringLiteral("mintempC")).toString().toDouble() : day.value(QStringLiteral("mintempF")).toString().toDouble();
        QJsonArray hourly = day.value(QStringLiteral("hourly")).toArray();
        QString hCode = QStringLiteral("113");
        if (hourly.size() > 4) hCode = hourly[4].toObject().value(QStringLiteral("weatherCode")).toString();
        QVariantMap di = iconForCode(hCode.toInt());
        QVariantMap entry;
        entry[QStringLiteral("date")] = date;
        entry[QStringLiteral("maxTemp")] = maxT;
        entry[QStringLiteral("minTemp")] = minT;
        entry[QStringLiteral("iconGlyph")] = di.value(QStringLiteral("glyph"));
        entry[QStringLiteral("iconColor")] = di.value(QStringLiteral("color"));
        forecast.append(entry);
    }
    if (m_forecast != forecast) { m_forecast = forecast; emit forecastChanged(); }
    m_lastUpdated = QDateTime::currentDateTime(); emit lastUpdatedChanged();
    setErrorMessage(QString());
}
