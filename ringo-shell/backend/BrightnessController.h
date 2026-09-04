#pragma once
#include <QObject>
#include <QFileSystemWatcher>
#include <QTimer>
#include <QtQml/qqml.h>

class BrightnessController final : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(int brightness READ brightness WRITE setBrightness NOTIFY brightnessChanged)
    Q_PROPERTY(int maxBrightness READ maxBrightness NOTIFY maxBrightnessChanged)
    Q_PROPERTY(double percent READ percent WRITE setPercent NOTIFY brightnessChanged)
    Q_PROPERTY(QString device READ device NOTIFY deviceChanged)

public:
    explicit BrightnessController(QObject *parent = nullptr);

    int brightness() const { return m_brightness; }
    int maxBrightness() const { return m_maxBrightness; }
    double percent() const {
        return m_maxBrightness > 0 ? static_cast<double>(m_brightness) / m_maxBrightness : 0.0;
    }
    QString device() const { return m_device; }

    Q_INVOKABLE void setBrightness(int value);
    Q_INVOKABLE void setPercent(double pct);
    Q_INVOKABLE void refresh();

signals:
    void brightnessChanged();
    void maxBrightnessChanged();
    void deviceChanged();

private slots:
    void onFileChanged(const QString &path);

private:
    void detectDevice();
    void readBrightness();

    QString m_device;
    QString m_devicePath;
    int m_brightness = 0;
    int m_maxBrightness = 100;
    QFileSystemWatcher m_watcher;
    QTimer m_pollTimer;
};
