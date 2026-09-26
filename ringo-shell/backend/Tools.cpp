#include "Tools.h"

#include <QDir>
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
