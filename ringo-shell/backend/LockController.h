#pragma once

#include <QObject>
#include <QString>
#include <QtQml/qqml.h>

// PAM-backed lock/unlock for the lockscreen: tryUnlock() runs the system-auth
// stack on a worker thread, so the GUI thread never blocks on it.
class LockController final : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool locked READ locked NOTIFY lockedChanged)
    Q_PROPERTY(bool authenticating READ authenticating NOTIFY authenticatingChanged)

public:
    explicit LockController(QObject *parent = nullptr);

    bool locked() const;
    bool authenticating() const;

    // Shows the lockscreen surface; only tryUnlock() or unlock() dismisses it.
    Q_INVOKABLE void lock();
    Q_INVOKABLE void unlock();

    // Asynchronous; the outcome arrives once via unlockResult(). Calls made
    // while a conversation is in flight are ignored.
    Q_INVOKABLE void tryUnlock(const QString &password);

signals:
    void lockedChanged();
    void authenticatingChanged();
    void unlockResult(bool success);

private:
    void setLocked(bool on);
    void setAuthenticating(bool on);

    // Runs on the GUI thread; publishes the outcome.
    void finishUnlock(bool success);

    bool m_locked = false;
    bool m_authenticating = false;
};
