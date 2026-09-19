#include "SoundController.h"
#include <QProcess>
#include <QFileInfo>
#include <QDir>
#include <QStandardPaths>
#include <QDebug>

SoundController::SoundController(QObject *parent)
    : QObject(parent)
{
    if (!QStandardPaths::findExecutable(QStringLiteral("pw-play")).isEmpty()) {
        m_playerBinary = QStringLiteral("pw-play");
    } else if (!QStandardPaths::findExecutable(QStringLiteral("canberra-gtk-play")).isEmpty()) {
        m_playerBinary = QStringLiteral("canberra-gtk-play");
    } else if (!QStandardPaths::findExecutable(QStringLiteral("paplay")).isEmpty()) {
        m_playerBinary = QStringLiteral("paplay");
    }
}

QString SoundController::resolveSoundPath(const QString &sound) const
{
    if (sound.isEmpty()) return QString();

    QString path = sound;
    if (path.startsWith(QStringLiteral("~/"))) {
        path = QDir::homePath() + path.mid(1);
    }

    if (QFileInfo::exists(path)) {
        return path;
    }

    // Try standard freedesktop stereo directory
    const QString baseDir = QStringLiteral("/usr/share/sounds/freedesktop/stereo/");
    const QStringList extensions = {QStringLiteral(".oga"), QStringLiteral(".ogg"), QStringLiteral(".wav")};

    for (const auto &ext : extensions) {
        QString candidate = baseDir + sound;
        if (!candidate.endsWith(ext)) {
            candidate += ext;
        }
        if (QFileInfo::exists(candidate)) {
            return candidate;
        }
    }

    return QString();
}

void SoundController::play(const QString &soundNameOrPath)
{
    QString resolved = resolveSoundPath(soundNameOrPath);
    if (resolved.isEmpty()) {
        if (m_playerBinary == QStringLiteral("canberra-gtk-play")) {
            // canberra-gtk-play can take event id directly: -i <event_id>
            QProcess::startDetached(QStringLiteral("canberra-gtk-play"), {QStringLiteral("-i"), soundNameOrPath});
            return;
        }
        qWarning() << "SoundController: Could not find sound" << soundNameOrPath;
        return;
    }

    if (!m_playerBinary.isEmpty()) {
        if (m_playerBinary == QStringLiteral("canberra-gtk-play")) {
            QProcess::startDetached(m_playerBinary, {QStringLiteral("-f"), resolved});
        } else {
            QProcess::startDetached(m_playerBinary, {resolved});
        }
    }
}

void SoundController::playAlarm()
{
    play(QStringLiteral("alarm-clock-elapsed"));
}

void SoundController::playComplete()
{
    play(QStringLiteral("complete"));
}

void SoundController::playBell()
{
    play(QStringLiteral("bell"));
}

void SoundController::playCamera()
{
    play(QStringLiteral("camera-shutter"));
}

void SoundController::playWarning()
{
    play(QStringLiteral("dialog-warning"));
}
