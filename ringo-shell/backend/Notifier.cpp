#include "Notifier.h"

#include "StateStore.h"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QVariantMap>

namespace {
const QString kDndKey = QStringLiteral("notification.dnd");
} // namespace

Notifier::Notifier(QObject *parent) : QObject(parent) {
    // Quiet Mode is user intent, so it is restored before the UI ever binds to it.
    m_dndEnabled = StateStore::instance().get(kDndKey, false).toBool();
}

bool Notifier::dndEnabled() const { return m_dndEnabled; }

void Notifier::setDndEnabled(bool on) {
    if (m_dndEnabled == on) return;
    m_dndEnabled = on;
    StateStore::instance().set(kDndKey, on);
    emit dndEnabledChanged();
}

void Notifier::post(const QString &summary, const QString &body, const QString &icon,
                    const QString &appName, int urgency, int timeoutMs) {
    QVariantMap hints;
    hints.insert(QStringLiteral("urgency"),
                 QVariant::fromValue<uchar>(static_cast<uchar>(qBound(0, urgency, 2))));

    QDBusMessage message = QDBusMessage::createMethodCall(
        QStringLiteral("org.freedesktop.Notifications"),
        QStringLiteral("/org/freedesktop/Notifications"),
        QStringLiteral("org.freedesktop.Notifications"),
        QStringLiteral("Notify"));
    message << appName << 0u << icon << summary << body << QStringList() << hints
            << timeoutMs;

    QDBusConnection::sessionBus().call(message, QDBus::NoBlock);
}
