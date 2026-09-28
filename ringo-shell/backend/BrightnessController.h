#pragma once

#include <QObject>
#include <QFileSystemWatcher>
#include <QtQml/qqml.h>

class BrightnessController final : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(int brightness READ brightness WRITE setBrightness NOTIFY brightnessChanged)
    Q_PROPERTY(double percent READ percent WRITE setPercent NOTIFY brightnessChanged)

public:
    explicit BrightnessController(QObject *parent = nullptr);

    int brightness() const { return m_brightness; }
    double percent() const {
        return m_maxBrightness > 0 ? static_cast<double>(m_brightness) / m_maxBrightness : 0.0;
    }

    Q_INVOKABLE void setBrightness(int value);
    Q_INVOKABLE void setPercent(double pct);
    // Mirrors `brightnessctl -e4 -n2 set N%+-`.
    Q_INVOKABLE void step(double deltaPercent);
    Q_INVOKABLE void dim();
    Q_INVOKABLE void restore();

signals:
    void brightnessChanged();

private slots:
    void onFileChanged(const QString &path);
    void onDirectoryChanged(const QString &path);
    void onPrepareForSleep(bool goingToSleep);

private:
    void detectDevice();
    void readBrightness();
    void rearmWatcher();

    QString m_device;
    QString m_devicePath;
    QString m_backlightDir;
    int m_brightness = 0;
    int m_maxBrightness = 100;
    int m_savedBrightness = -1;
    QFileSystemWatcher m_watcher;
};
