#pragma once
#include <QObject>
#include <QString>
#include <QtQml/qqml.h>

// Posts desktop notifications through the shell's own notification server.
// Fire-and-forget call to itself: waiting for the reply would deadlock.
class Notifier final : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool dndEnabled READ dndEnabled WRITE setDndEnabled NOTIFY dndEnabledChanged)

public:
    explicit Notifier(QObject *parent = nullptr);

    bool dndEnabled() const;
    void setDndEnabled(bool on); // persisted so Quiet Mode survives a restart

    // `icon` is a themed name or absolute path; `timeoutMs` < 0 lets the server decide.
    Q_INVOKABLE void post(const QString &summary,
                          const QString &body = QString(),
                          const QString &icon = QString(),
                          const QString &appName = QStringLiteral("Ringo"),
                          int urgency = 1,
                          int timeoutMs = -1);

signals:
    void dndEnabledChanged();

private:
    bool m_dndEnabled = false;
};
