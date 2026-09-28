#pragma once
#include <QObject>
#include <QString>
#include <QtQml/qqml.h>

// Host facts QML cannot answer on its own, used by Doctor.qml to produce the
// `ringo-shell call doctor check` report.
class Tools final : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit Tools(QObject *parent = nullptr);

    // Empty when `command` is not installed.
    Q_INVOKABLE QString which(const QString &command) const;
    Q_INVOKABLE bool have(const QString &command) const;
    Q_INVOKABLE bool fileExists(const QString &path) const;

    // Empty when unreadable; `~` is expanded.
    Q_INVOKABLE QString readText(const QString &path) const;

    Q_INVOKABLE QString version() const;
};
