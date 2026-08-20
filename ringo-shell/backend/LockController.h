#pragma once

#include <QObject>
#include <QString>
#include <QtQml/qqml.h>

// PAM-backed lock/unlock for the ringo-shell lockscreen.
// tryUnlock() authenticates the current user's password against the
// system-auth PAM stack, so the lock screen never touches /etc/shadow directly.
class LockController final : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool locked READ locked NOTIFY lockedChanged)

public:
    explicit LockController(QObject *parent = nullptr);

    bool locked() const;

    // Locks the session. Shows the lockscreen surface; only tryUnlock() (or
    // calling unlock()) can dismiss it.
    Q_INVOKABLE void lock();
    Q_INVOKABLE void unlock();

    // Authenticates against PAM. Returns true when the password is correct.
    // On success the session is unlocked as a side effect.
    Q_INVOKABLE bool tryUnlock(const QString &password);

signals:
    void lockedChanged();

private:
    void setLocked(bool on);

    bool m_locked = false;
};