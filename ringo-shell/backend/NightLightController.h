#pragma once
#include <QElapsedTimer>
#include <QObject>
#include <QString>
#include <QThread>
#include <QtQml/qqml.h>

// Night light: warms the screen after sunset and cools it back during the day,
// following the sun for the configured coordinates.
//
// The gamma ramp is applied by the in-process engine
// (backend/engines/nightlight/nightlight.c), which owns a Wayland connection and
// therefore runs on its own thread. Changing any option restarts that thread
// with the new values; the GUI thread is never blocked on it.
class NightLightController final : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(bool active READ active NOTIFY activeChanged)
    Q_PROPERTY(int temperature READ temperature NOTIFY temperatureChanged)
    Q_PROPERTY(int outputs READ outputs NOTIFY outputsChanged)
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
    int outputs() const { return m_outputs; }
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
    // off, high (day temperature) or low (night temperature). "high"/"low"
    // pin the screen regardless of the sun, which is what the testing and the
    // manual override in the control center use.
    void setForce(const QString &force);

    // Coordinates from the weather widget. Ignored while the location was set
    // explicitly (config.jsonc or the IPC), so a city change cannot silently
    // move a location the user pinned by hand.
    Q_INVOKABLE void setAutoLocation(double latitude, double longitude);
    // Drops the explicit location, letting the automatic one take over again.
    Q_INVOKABLE void clearLocationOverride();

    // Starts the engine when the night light is enabled. Safe to call twice.
    Q_INVOKABLE void start();
    // Disables the night light and stops the engine; the configuration is kept,
    // so start() revives it.
    Q_INVOKABLE void stop();
    // Restarts the engine, re-reading the current configuration.
    Q_INVOKABLE void reload();

signals:
    void enabledChanged();
    void activeChanged();
    void temperatureChanged();
    void outputsChanged();
    void latitudeChanged();
    void longitudeChanged();
    void lowTemperatureChanged();
    void highTemperatureChanged();
    void gammaChanged();
    void forceChanged();
    void locationExplicitChanged();
    void errorChanged();

private:
    static void statusCallback(const struct ringo_nightlight_status *status, void *user);

    void setActive(bool active);
    void setTemperature(int kelvin);
    void setOutputs(int outputs);
    void setError(const QString &error);

    void startEngine();
    void stopEngine();
    void restartEngine();
    void onEngineFinished(QThread *thread);

    bool m_enabled = true;
    bool m_active = false;
    int m_temperature = 0;
    int m_outputs = 0;
    double m_latitude = 11.0;
    double m_longitude = 105.0;
    int m_lowTemperature = 4000;
    int m_highTemperature = 6500;
    double m_gamma = 1.0;
    QString m_force = QStringLiteral("off");
    bool m_locationExplicit = false;
    QString m_error;
    int m_restarts = 0;
    QElapsedTimer m_engineAlive;      // how long the current engine has been up
    QThread *m_engineThread = nullptr; // resident night-light engine thread
};
