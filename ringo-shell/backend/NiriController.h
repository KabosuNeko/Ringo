#pragma once
#include <QObject>
#include <QtQml/qqml.h>

// One-shot dispatcher for niri IPC actions (quit, power off monitors, suspend...).
// Holds no long-lived connection to niri.
class NiriController final : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit NiriController(QObject *parent = nullptr);

    Q_INVOKABLE void action(const QString &actionName);
    Q_INVOKABLE void quit();
    Q_INVOKABLE void powerOffMonitors();
    Q_INVOKABLE void powerOnMonitors();
    Q_INVOKABLE void suspend();
    Q_INVOKABLE void reboot();
    Q_INVOKABLE void powerOff();

private:
    QString findNiriSocket();

    QString m_socketPath;
};
