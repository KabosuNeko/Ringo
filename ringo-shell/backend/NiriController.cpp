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
        // niri may have (re)started since we resolved the socket - retry once.
        m_socketPath = findNiriSocket();
        if (m_socketPath.isEmpty()) return;
    }

    QLocalSocket sock;
    sock.connectToServer(m_socketPath);
    if (sock.waitForConnected(300)) {
        const QString cmd = QStringLiteral("{\"Action\":{\"%1\":{}}}\n").arg(actionName);
        sock.write(cmd.toUtf8());
        sock.flush();
        sock.waitForBytesWritten(300);
        sock.disconnectFromServer();
    }
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
