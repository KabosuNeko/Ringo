#include "NiriController.h"
#include <QDir>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QLocalSocket>
#include <unistd.h>

NiriController::NiriController(QObject *parent) : QObject(parent) {
    m_socketPath = findNiriSocket();
}

QString NiriController::findNiriSocket() {
    const QString envSocket = qEnvironmentVariable("NIRI_SOCKET");
    if (!envSocket.isEmpty() && QFile::exists(envSocket)) {
        return envSocket;
    }

    const QString userRuntime = QStringLiteral("/run/user/%1").arg(getuid());
    QDir runtimeDir(userRuntime);
    const QStringList socks = runtimeDir.entryList(QStringList{QStringLiteral("niri.*.sock")}, QDir::Files | QDir::System);
    if (!socks.isEmpty()) {
        return runtimeDir.filePath(socks.first());
    }
    return {};
}

void NiriController::action(const QString &actionName) {
    if (m_socketPath.isEmpty()) {
        m_socketPath = findNiriSocket();
        if (m_socketPath.isEmpty()) return;
    }

    auto *sock = new QLocalSocket(this);
    const QByteArray payload = QStringLiteral("{\"Action\":{\"%1\":{}}}\n").arg(actionName).toUtf8();
    connect(sock, &QLocalSocket::connected, this, [sock, payload]() {
        sock->write(payload);
        sock->flush();
        sock->disconnectFromServer();
    });
    connect(sock, &QLocalSocket::disconnected, sock, &QObject::deleteLater);
    connect(sock, &QLocalSocket::errorOccurred, sock, &QObject::deleteLater);
    sock->connectToServer(m_socketPath);
}

void NiriController::quit() {
    action(QStringLiteral("Quit"));
}

void NiriController::powerOffMonitors() {
    action(QStringLiteral("PowerOffMonitors"));
}

void NiriController::powerOnMonitors() {
    action(QStringLiteral("PowerOnMonitors"));
}

void NiriController::suspend() {
    QDBusMessage msg = QDBusMessage::createMethodCall(
        QStringLiteral("org.freedesktop.login1"),
        QStringLiteral("/org/freedesktop/login1"),
        QStringLiteral("org.freedesktop.login1.Manager"),
        QStringLiteral("Suspend"));
    msg << true;
    QDBusConnection::systemBus().send(msg);
}

void NiriController::reboot() {
    QDBusMessage msg = QDBusMessage::createMethodCall(
        QStringLiteral("org.freedesktop.login1"),
        QStringLiteral("/org/freedesktop/login1"),
        QStringLiteral("org.freedesktop.login1.Manager"),
        QStringLiteral("Reboot"));
    msg << true;
    QDBusConnection::systemBus().send(msg);
}

void NiriController::powerOff() {
    QDBusMessage msg = QDBusMessage::createMethodCall(
        QStringLiteral("org.freedesktop.login1"),
        QStringLiteral("/org/freedesktop/login1"),
        QStringLiteral("org.freedesktop.login1.Manager"),
        QStringLiteral("PowerOff"));
    msg << true;
    QDBusConnection::systemBus().send(msg);
}
