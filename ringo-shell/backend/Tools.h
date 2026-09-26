#pragma once
#include <QObject>
#include <QString>
#include <QtQml/qqml.h>

// Host facts the QML side cannot answer on its own: which tools exist, whether
// a file is readable, and what this build is. Used by Doctor.qml to produce the
// `ringo-shell call doctor check` report.
class Tools final : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit Tools(QObject *parent = nullptr);

    // Absolute path of `command`, or an empty string when it is not installed.
    Q_INVOKABLE QString which(const QString &command) const;
    Q_INVOKABLE bool have(const QString &command) const;
    Q_INVOKABLE bool fileExists(const QString &path) const;

    // "Ringo 1.0.0 · Qt 6.11.2"
    Q_INVOKABLE QString version() const;
};
