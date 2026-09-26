#pragma once
#include <QObject>
#include <QString>
#include <QtQml/qqml.h>

// Posts desktop notifications through the shell's own notification server.
//
// The shell *is* the org.freedesktop.Notifications service, so this is a
// fire-and-forget D-Bus call to itself: no notify-send process, and no reply to
// wait for (a blocking call would deadlock, since the answer would have to be
// produced by this same event loop).
class Notifier final : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit Notifier(QObject *parent = nullptr);

    // `icon` is a themed icon name or an absolute path; `urgency` is 0 low,
    // 1 normal, 2 critical; `timeoutMs` < 0 lets the server decide.
    Q_INVOKABLE void post(const QString &summary,
                          const QString &body = QString(),
                          const QString &icon = QString(),
                          const QString &appName = QStringLiteral("Ringo"),
                          int urgency = 1,
                          int timeoutMs = -1);
};
