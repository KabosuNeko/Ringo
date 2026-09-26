#pragma once

#include <QObject>
#include <QString>
#include <QtQml/qqml.h>

// PAM-backed lock/unlock for the ringo-shell lockscreen.
// tryUnlock() authenticates the current user's password against the
// system-auth PAM stack on a worker thread, so the lock screen never touches
// /etc/shadow directly and the GUI thread never blocks on the password hash.
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

    // Locks the session. Shows the lockscreen surface; only tryUnlock() (or
    // calling unlock()) can dismiss it.
    Q_INVOKABLE void lock();
    Q_INVOKABLE void unlock();

    // Starts an asynchronous PAM authentication and returns immediately. The
    // outcome is delivered once via unlockResult(). Calls issued while another
    // conversation is still in flight are ignored, so at most one PAM
    // conversation ever runs at a time.
    Q_INVOKABLE void tryUnlock(const QString &password);

signals:
    void lockedChanged();
    void authenticatingChanged();
    void unlockResult(bool success);

private:
    void setLocked(bool on);
    void setAuthenticating(bool on);

    // Runs on the GUI thread once the worker is done; publishes the outcome.
    void finishUnlock(bool success);

    bool m_locked = false;
    bool m_authenticating = false;
};
