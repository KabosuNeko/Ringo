#pragma once
#include <QObject>
#include <QtQml/qqml.h>

// One-shot dispatcher for niri IPC actions (quit, power off monitors, suspend...).
//
// This used to also hold a permanent "EventStream" connection plus a second
// socket that re-queried `"Windows"` on every window/workspace event, purely to
// compute a `fullscreenActive` flag from a window JSON field (`is_fullscreen`)
// that niri does not send - the flag could never become true. Both sockets are
// gone: the event stream existed only to drive that dead query, so the class no
// longer keeps any long-lived connection to niri.
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
