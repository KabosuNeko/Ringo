#pragma once
#include <QElapsedTimer>
#include <QObject>
#include <QProcess>
#include <QString>
#include <QTimer>
#include <QtQml/qqml.h>

// Night light via the upstream `wlsunset` process: reads the applied temperature
// from its stderr and forwards the manual override as SIGUSR1.
class NightLightController final : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(bool active READ active NOTIFY activeChanged)
    Q_PROPERTY(int temperature READ temperature NOTIFY temperatureChanged)
    Q_PROPERTY(double latitude READ latitude WRITE setLatitude NOTIFY latitudeChanged)
    Q_PROPERTY(double longitude READ longitude WRITE setLongitude NOTIFY longitudeChanged)
    Q_PROPERTY(int lowTemperature READ lowTemperature WRITE setLowTemperature NOTIFY lowTemperatureChanged)
    Q_PROPERTY(int highTemperature READ highTemperature WRITE setHighTemperature NOTIFY highTemperatureChanged)
    Q_PROPERTY(double gamma READ gamma WRITE setGamma NOTIFY gammaChanged)
    Q_PROPERTY(QString force READ force WRITE setForce NOTIFY forceChanged)
    Q_PROPERTY(bool locationExplicit READ locationExplicit NOTIFY locationExplicitChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)

public:
    explicit NightLightController(QObject *parent = nullptr);
    ~NightLightController() override;

    bool enabled() const { return m_enabled; }
    bool active() const { return m_active; }
    int temperature() const { return m_temperature; }
    double latitude() const { return m_latitude; }
    double longitude() const { return m_longitude; }
    int lowTemperature() const { return m_lowTemperature; }
    int highTemperature() const { return m_highTemperature; }
    double gamma() const { return m_gamma; }
    QString force() const { return m_force; }
    bool locationExplicit() const { return m_locationExplicit; }
    QString error() const { return m_error; }

    void setEnabled(bool enabled);
    void setLatitude(double latitude);
    void setLongitude(double longitude);
    void setLowTemperature(int kelvin);
    void setHighTemperature(int kelvin);
    void setGamma(double gamma);
    // off, high (day) or low (night); "high"/"low" pin the screen regardless of
    // the sun, which is what the control center's manual override uses.
    void setForce(const QString &force);

    // Coordinates from the weather widget; ignored while the location is pinned
    // explicitly (config.jsonc or IPC).
    Q_INVOKABLE void setAutoLocation(double latitude, double longitude);
    // Drops the explicit location.
    Q_INVOKABLE void clearLocationOverride();

    Q_INVOKABLE void start();

signals:
    void enabledChanged();
    void activeChanged();
    void temperatureChanged();
    void latitudeChanged();
    void longitudeChanged();
    void lowTemperatureChanged();
    void highTemperatureChanged();
    void gammaChanged();
    void forceChanged();
    void locationExplicitChanged();
    void errorChanged();

private:
    void setActive(bool active);
    void setTemperature(int kelvin);
    void setError(const QString &error);
    void setForceInternal(const QString &force);

    void startEngine();
    void stopEngine();
    void restartEngine();
    void readEngineOutput();
    void applyForce();

    bool m_enabled = true;
    bool m_active = false;
    int m_temperature = 0;
    double m_latitude = 11.0;
    double m_longitude = 105.0;
    int m_lowTemperature = 4000;
    int m_highTemperature = 6500;
    double m_gamma = 1.0;
    QString m_force = QStringLiteral("off");
    bool m_locationExplicit = false;
    QString m_error;
    int m_restarts = 0;
    bool m_stopping = false;
    bool m_gammaRetryUsed = false; // one retry per start for a held output
    QElapsedTimer m_uptime;
    QString m_appliedForce = QStringLiteral("off"); // what wlsunset reported back
    QProcess m_process;
    QTimer m_restartTimer;
};
