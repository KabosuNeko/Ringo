#include "LockController.h"

#include <QByteArray>
#include <QMetaObject>
#include <QPointer>
#include <QThreadPool>

#include <security/pam_appl.h>

#include <cstdlib>
#include <cstring>

namespace {

// PAM conversation: the only prompt we expect is the password echo-off prompt.
// We answer it with the password supplied by tryUnlock(). Every other message
// style (errors, text info) is left untouched so PAM can surface it itself.
struct ConversationData {
    const char *password;
};

int conversation(int numMsg, const struct pam_message **msg,
                 struct pam_response **resp, void *data) {
    auto *convData = static_cast<ConversationData *>(data);
    auto *responses = static_cast<struct pam_response *>(
        calloc(static_cast<size_t>(numMsg), sizeof(struct pam_response)));
    if (responses == nullptr) {
        return PAM_BUF_ERR;
    }

    for (int i = 0; i < numMsg; ++i) {
        const int style = msg[i]->msg_style;
        if (style == PAM_PROMPT_ECHO_OFF || style == PAM_PROMPT_ECHO_ON) {
            responses[i].resp = strdup(convData->password);
            if (responses[i].resp == nullptr) {
                for (int j = 0; j < i; ++j) {
                    free(responses[j].resp);
                }
                free(responses);
                return PAM_BUF_ERR;
            }
        }
    }

    *resp = responses;
    return PAM_SUCCESS;
}

// Runs the whole PAM conversation on the calling (worker) thread. `password`
// is owned by the caller, which wipes it once this returns.
bool authenticate(const QByteArray &user, const QByteArray &password) {
    ConversationData data{password.constData()};
    struct pam_conv conv = {conversation, &data};
    pam_handle_t *handle = nullptr;

    int result = pam_start("system-auth", user.constData(), &conv, &handle);
    if (result != PAM_SUCCESS) {
        return false;
    }

    result = pam_authenticate(handle, 0);
    if (result == PAM_SUCCESS) {
        result = pam_acct_mgmt(handle, 0);
    }

    pam_end(handle, result);
    return result == PAM_SUCCESS;
}

} // namespace

LockController::LockController(QObject *parent)
    : QObject(parent) {}

bool LockController::locked() const {
    return m_locked;
}

bool LockController::authenticating() const {
    return m_authenticating;
}

void LockController::lock() {
    setLocked(true);
}

void LockController::unlock() {
    setLocked(false);
}

void LockController::tryUnlock(const QString &password) {
    // A conversation is already running: drop this attempt instead of stacking
    // a second PAM conversation on top of it.
    if (m_authenticating) {
        return;
    }

    const QByteArray user = qgetenv("USER");
    if (user.isEmpty() || password.isEmpty()) {
        emit unlockResult(false);
        return;
    }

    setAuthenticating(true);

    // The singleton outlives every attempt, but guard anyway so a late worker
    // result can never touch a destroyed object.
    QPointer<LockController> guard(this);
    QThreadPool::globalInstance()->start(
        [guard, user, password = password.toUtf8()]() mutable {
            const bool ok = authenticate(user, password);
            // The password copy lives and dies on this worker thread.
            password.fill('\0');

            if (!guard) {
                return;
            }
            QMetaObject::invokeMethod(
                guard.data(),
                [guard, ok]() {
                    if (LockController *self = guard.data()) {
                        self->finishUnlock(ok);
                    }
                },
                Qt::QueuedConnection);
        });
}

void LockController::finishUnlock(bool success) {
    setAuthenticating(false);
    if (success) {
        setLocked(false);
    }
    emit unlockResult(success);
}

void LockController::setLocked(bool on) {
    if (m_locked == on) {
        return;
    }
    m_locked = on;
    emit lockedChanged();
}

void LockController::setAuthenticating(bool on) {
    if (m_authenticating == on) {
        return;
    }
    m_authenticating = on;
    emit authenticatingChanged();
}
