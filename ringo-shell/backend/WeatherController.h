#pragma once
#include <QObject>
#include <QTimer>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QDateTime>
#include <QVariantList>
#include <QtQml/qqml.h>

class WeatherController final : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(double temp READ temp NOTIFY tempChanged)
    Q_PROPERTY(double feelsLike READ feelsLike NOTIFY feelsLikeChanged)
    Q_PROPERTY(int humidity READ humidity NOTIFY humidityChanged)
    Q_PROPERTY(double windSpeed READ windSpeed NOTIFY windSpeedChanged)
    Q_PROPERTY(QString condition READ condition NOTIFY conditionChanged)
    Q_PROPERTY(QString iconGlyph READ iconGlyph NOTIFY iconGlyphChanged)
    Q_PROPERTY(QString iconColor READ iconColor NOTIFY iconColorChanged)
    Q_PROPERTY(QString sunrise READ sunrise NOTIFY sunriseChanged)
    Q_PROPERTY(QString sunset READ sunset NOTIFY sunsetChanged)
    Q_PROPERTY(double latitude READ latitude NOTIFY coordinatesChanged)
    Q_PROPERTY(double longitude READ longitude NOTIFY coordinatesChanged)
    Q_PROPERTY(QVariantList forecast READ forecast NOTIFY forecastChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged)
    Q_PROPERTY(QDateTime lastUpdated READ lastUpdated NOTIFY lastUpdatedChanged)
    Q_PROPERTY(QString weatherLocation READ weatherLocation WRITE setWeatherLocation NOTIFY weatherLocationChanged)
    Q_PROPERTY(QString weatherUnits READ weatherUnits WRITE setWeatherUnits NOTIFY weatherUnitsChanged)
    Q_PROPERTY(int refreshInterval READ refreshInterval WRITE setRefreshInterval NOTIFY refreshIntervalChanged)

public:
    explicit WeatherController(QObject *parent = nullptr);

    double temp() const { return m_temp; }
    double feelsLike() const { return m_feelsLike; }
    int humidity() const { return m_humidity; }
    double windSpeed() const { return m_windSpeed; }
    QString condition() const { return m_condition; }
    QString iconGlyph() const { return m_iconGlyph; }
    QString iconColor() const { return m_iconColor; }
    QString sunrise() const { return m_sunrise; }
    QString sunset() const { return m_sunset; }
    double latitude() const { return m_latitude; }
    double longitude() const { return m_longitude; }
    QVariantList forecast() const { return m_forecast; }
    bool loading() const { return m_loading; }
    QString errorMessage() const { return m_errorMessage; }
    QDateTime lastUpdated() const { return m_lastUpdated; }
    QString weatherLocation() const { return m_weatherLocation; }
    QString weatherUnits() const { return m_weatherUnits; }
    int refreshInterval() const { return m_refreshInterval; }

    void setWeatherLocation(const QString &v);
    void setWeatherUnits(const QString &v);
    void setRefreshInterval(int v);

    Q_INVOKABLE void refresh();

signals:
    void tempChanged();
    void feelsLikeChanged();
    void humidityChanged();
    void windSpeedChanged();
    void conditionChanged();
    void iconGlyphChanged();
    void iconColorChanged();
    void sunriseChanged();
    void sunsetChanged();
    // Both coordinates are reported by the weather service's nearest area.
    void coordinatesChanged();
    void forecastChanged();
    void loadingChanged();
    void errorMessageChanged();
    void lastUpdatedChanged();
    void weatherLocationChanged();
    void weatherUnitsChanged();
    void refreshIntervalChanged();

private slots:
    void onReplyFinished();
    void onTimerTriggered();

private:
    void setLoading(bool v);
    void setErrorMessage(const QString &v);
    QVariantMap iconForCode(int code) const;
    void parseAndApply(const QByteArray &data);
    void loadCache();
    void saveCache(const QByteArray &data);
    QString cachePath() const;

    double m_temp = 0;
    double m_feelsLike = 0;
    int m_humidity = 0;
    double m_windSpeed = 0;
    QString m_condition;
    QString m_iconGlyph = QStringLiteral("\ue312");
    QString m_iconColor = QStringLiteral("#9aa0a6");
    QString m_sunrise;
    QString m_sunset;
    double m_latitude = 0;
    double m_longitude = 0;
    QVariantList m_forecast;
    bool m_loading = false;
    QString m_errorMessage;
    QDateTime m_lastUpdated = QDateTime::currentDateTime();

    QString m_weatherLocation = QStringLiteral("Hanoi");
    QString m_weatherUnits = QStringLiteral("metric");
    int m_refreshInterval = 3600000;

    QNetworkAccessManager m_nam;
    QTimer m_timer;
    QNetworkReply *m_reply = nullptr;
};
