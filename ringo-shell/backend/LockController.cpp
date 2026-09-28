#include "LockController.h"

#include <QByteArray>
#include <QMetaObject>
#include <QPointer>
#include <QThreadPool>

#include <security/pam_appl.h>

#include <cstdlib>
#include <cstring>

namespace {

// Answers the password echo-off prompt with the password from tryUnlock();
// other message styles are left to PAM so it can surface them itself.
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

// Runs on the calling (worker) thread; `password` is owned and wiped by the caller.
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
    // Drop rather than stack a second PAM conversation.
    if (m_authenticating) {
        return;
    }

    const QByteArray user = qgetenv("USER");
    if (user.isEmpty() || password.isEmpty()) {
        emit unlockResult(false);
        return;
    }

    setAuthenticating(true);

    // Guard so a late worker result cannot touch a destroyed object.
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
