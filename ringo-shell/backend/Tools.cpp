#include "Tools.h"

#include <QDateTime>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>
#include <QtGlobal>

#ifndef RINGO_VERSION
#define RINGO_VERSION "unknown"
#endif

Tools::Tools(QObject *parent) : QObject(parent) {}

QString Tools::which(const QString &command) const {
    return QStandardPaths::findExecutable(command);
}

bool Tools::have(const QString &command) const {
    return !QStandardPaths::findExecutable(command).isEmpty();
}

bool Tools::fileExists(const QString &path) const {
    QString resolved = path;
    if (resolved.startsWith(QStringLiteral("~/")))
        resolved = QDir::homePath() + resolved.mid(1);
    return QFileInfo::exists(resolved);
}

QString Tools::readText(const QString &path) const {
    QString resolved = path;
    if (resolved.startsWith(QStringLiteral("~/")))
        resolved = QDir::homePath() + resolved.mid(1);

    QFile file(resolved);
    if (!file.open(QIODevice::ReadOnly)) return QString();
    return QString::fromUtf8(file.readAll());
}

QString Tools::version() const {
    return QStringLiteral("Ringo %1 · Qt %2").arg(QStringLiteral(RINGO_VERSION), QString::fromLatin1(qVersion()));
}

QString Tools::backendStale() const {
    // The deployed plugin is a copy of a build, so a `git pull` leaves it behind
    // the sources until install.sh runs again.
    const QString config = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
        + QStringLiteral("/ringo-shell");
    const QString theme = config + QStringLiteral("/Theme.qml");
    const QString plugin = config + QStringLiteral("/IslandBackend/libIslandBackend.so");
    if (!QFileInfo(theme).isSymLink() || !QFileInfo::exists(plugin)) return QString();

    // A stow symlink points into the checkout: <repo>/home/.config/ringo-shell/...
    const QString suffix = QStringLiteral("/home/.config/ringo-shell/Theme.qml");
    const QString real = QFileInfo(theme).canonicalFilePath();
    if (real.isEmpty() || !real.endsWith(suffix)) return QString();
    const QString repo = real.chopped(suffix.size());

    const QDateTime built = QFileInfo(plugin).lastModified();
    QDirIterator it(repo + QStringLiteral("/ringo-shell/backend"),
                    {QStringLiteral("*.c"), QStringLiteral("*.h"), QStringLiteral("*.cpp"),
                     QStringLiteral("*.xml")},
                    QDir::Files, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        if (QFileInfo(it.next()).lastModified() > built)
            return QStringLiteral("backend plugin is older than the source (run install.sh)");
    }
    return QString();
}
