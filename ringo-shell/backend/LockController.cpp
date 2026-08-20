#include "LockController.h"

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

} // namespace

LockController::LockController(QObject *parent)
    : QObject(parent) {}

bool LockController::locked() const {
    return m_locked;
}

void LockController::lock() {
    setLocked(true);
}

void LockController::unlock() {
    setLocked(false);
}

bool LockController::tryUnlock(const QString &password) {
    const QByteArray user = qgetenv("USER");
    const QByteArray pass = password.toUtf8();
    if (user.isEmpty() || pass.isEmpty()) {
        return false;
    }

    ConversationData data{pass.constData()};
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

    const bool ok = (result == PAM_SUCCESS);
    if (ok) {
        setLocked(false);
    }
    return ok;
}

void LockController::setLocked(bool on) {
    if (m_locked == on) {
        return;
    }
    m_locked = on;
    emit lockedChanged();
}