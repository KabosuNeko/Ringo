#include "Notifier.h"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QVariantMap>

Notifier::Notifier(QObject *parent) : QObject(parent) {}

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
