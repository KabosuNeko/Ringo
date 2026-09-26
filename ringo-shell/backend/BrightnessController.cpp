#include "BrightnessController.h"
#include <QDir>
#include <QFile>
#include <QDBusConnection>
#include <QDBusMessage>
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
        rearmWatcher();
        connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, &BrightnessController::onFileChanged);
        connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, &BrightnessController::onDirectoryChanged);
    }

    // A 2.5s fallback poll used to live here. It is not needed: inotify on the
    // sysfs attribute delivers external changes (logind, the compositor, Fn
    // keys) and this is verified empirically. The two cases the poll was papering
    // over - the attribute being replaced, and the node disappearing across
    // suspend/resume - are handled explicitly below without polling.
    QDBusConnection::systemBus().connect(
        QStringLiteral("org.freedesktop.login1"),
        QStringLiteral("/org/freedesktop/login1"),
        QStringLiteral("org.freedesktop.login1.Manager"),
        QStringLiteral("PrepareForSleep"),
        this, SLOT(onPrepareForSleep(bool)));
}

void BrightnessController::rearmWatcher() {
    if (!m_devicePath.isEmpty() && QFile::exists(m_devicePath + QStringLiteral("/brightness"))) {
        const QString brightFile = m_devicePath + QStringLiteral("/brightness");
        if (!m_watcher.files().contains(brightFile)) m_watcher.addPath(brightFile);
    }
    if (!m_backlightDir.isEmpty() && QDir(m_backlightDir).exists()) {
        if (!m_watcher.directories().contains(m_backlightDir)) m_watcher.addPath(m_backlightDir);
    }
}

void BrightnessController::onPrepareForSleep(bool goingToSleep) {
    if (goingToSleep) return;
    // The backlight class device can be unregistered and re-registered across a
    // suspend/resume cycle, which drops the inotify watch silently. Re-arm and
    // re-read so the bar cannot show a stale value after waking.
    rearmWatcher();
    readBrightness();
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
    m_backlightDir = backlightDir.absolutePath();
}

void BrightnessController::readBrightness() {
    if (m_devicePath.isEmpty()) return;

    bool ok = false;
    const int maxVal = readSysfsFile(m_devicePath + QStringLiteral("/max_brightness")).toInt(&ok);
    if (ok && maxVal > 0) {
        m_maxBrightness = maxVal;
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
    // QFileSystemWatcher drops the watch when a sysfs attribute is replaced (the
    // new inode is not watched). Re-arm everything so we keep receiving events.
    rearmWatcher();
    Q_UNUSED(path);
}

void BrightnessController::onDirectoryChanged(const QString &path) {
    // The backlight class directory changed: the attribute may have been
    // recreated (driver reload, resume). Re-arm and re-read.
    rearmWatcher();
    readBrightness();
    Q_UNUSED(path);
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

void BrightnessController::step(double deltaPercent) {
    if (m_maxBrightness <= 0) return;

    // Same curve as `brightnessctl -e4`: the value the user sees is
    // (raw / max)^(1/4) * 100, so a step is applied on that percentage and
    // mapped back to a raw value through the exponent.
    constexpr double kExponent = 4.0;
    const double rawFraction = static_cast<double>(m_brightness) / m_maxBrightness;
    const double currentPct = std::pow(rawFraction, 1.0 / kExponent) * 100.0;
    const double targetPct = std::clamp(currentPct + deltaPercent, 0.0, 100.0);
    const double raw = std::pow(targetPct / 100.0, kExponent) * m_maxBrightness;
    setBrightness(static_cast<int>(std::round(raw)));
}

void BrightnessController::dim() {
    if (m_maxBrightness <= 0) return;
    m_savedBrightness = m_brightness;
    const int dimVal = std::max(1, static_cast<int>(std::round(0.10 * m_maxBrightness)));
    setBrightness(dimVal);
}

void BrightnessController::restore() {
    if (m_savedBrightness > 0) {
        setBrightness(m_savedBrightness);
        m_savedBrightness = -1;
    }
}
