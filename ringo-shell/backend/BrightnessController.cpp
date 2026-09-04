#include "BrightnessController.h"
#include <QDir>
#include <QFile>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDebug>
#include <algorithm>
#include <cmath>

namespace {
QString readSysfsFile(const QString &path) {
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return {};
    return QString::fromUtf8(f.readAll()).trimmed();
}
}

BrightnessController::BrightnessController(QObject *parent) : QObject(parent) {
    detectDevice();
    readBrightness();

    if (!m_devicePath.isEmpty()) {
        const QString brightFile = m_devicePath + QStringLiteral("/brightness");
        m_watcher.addPath(brightFile);
        connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, &BrightnessController::onFileChanged);
    }

    // Fallback timer every 2.5 seconds in case sysfs inotify events are missed
    m_pollTimer.setInterval(2500);
    m_pollTimer.setSingleShot(false);
    connect(&m_pollTimer, &QTimer::timeout, this, &BrightnessController::readBrightness);
    m_pollTimer.start();
}

void BrightnessController::detectDevice() {
    QDir backlightDir(QStringLiteral("/sys/class/backlight"));
    if (!backlightDir.exists()) return;

    const QStringList entries = backlightDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    if (entries.isEmpty()) return;

    QString chosen = entries.first();
    for (const QString &entry : entries) {
        const QString typePath = backlightDir.filePath(entry) + QStringLiteral("/type");
        if (readSysfsFile(typePath) == QStringLiteral("raw")) {
            chosen = entry;
            break;
        }
    }

    m_device = chosen;
    m_devicePath = backlightDir.filePath(chosen);
    emit deviceChanged();
}

void BrightnessController::readBrightness() {
    if (m_devicePath.isEmpty()) return;

    bool ok = false;
    const int maxVal = readSysfsFile(m_devicePath + QStringLiteral("/max_brightness")).toInt(&ok);
    if (ok && maxVal > 0 && maxVal != m_maxBrightness) {
        m_maxBrightness = maxVal;
        emit maxBrightnessChanged();
    }

    // Try actual_brightness first, fallback to brightness
    QString currentStr = readSysfsFile(m_devicePath + QStringLiteral("/actual_brightness"));
    if (currentStr.isEmpty()) {
        currentStr = readSysfsFile(m_devicePath + QStringLiteral("/brightness"));
    }

    const int curVal = currentStr.toInt(&ok);
    if (ok && curVal != m_brightness) {
        m_brightness = curVal;
        emit brightnessChanged();
    }
}

void BrightnessController::onFileChanged(const QString &path) {
    readBrightness();
    // QFileSystemWatcher sometimes removes files on sysfs modifications; re-add if missing
    if (!m_watcher.files().contains(path) && QFile::exists(path)) {
        m_watcher.addPath(path);
    }
}

void BrightnessController::setBrightness(int value) {
    if (m_device.isEmpty() || m_maxBrightness <= 0) return;

    const int clamped = std::clamp(value, 1, m_maxBrightness);
    if (clamped == m_brightness) return;

    m_brightness = clamped;
    emit brightnessChanged();

    // Call systemd-logind via DBus to set brightness without root permissions
    QDBusMessage msg = QDBusMessage::createMethodCall(
        QStringLiteral("org.freedesktop.login1"),
        QStringLiteral("/org/freedesktop/login1/session/auto"),
        QStringLiteral("org.freedesktop.login1.Session"),
        QStringLiteral("SetBrightness")
    );
    msg << QStringLiteral("backlight") << m_device << static_cast<uint32_t>(clamped);
    QDBusConnection::systemBus().send(msg);
}

void BrightnessController::setPercent(double pct) {
    if (m_maxBrightness <= 0) return;
    const double clampedPct = std::clamp(pct, 0.01, 1.0);
    const int val = static_cast<int>(std::round(clampedPct * m_maxBrightness));
    setBrightness(val);
}

void BrightnessController::refresh() {
    readBrightness();
}
