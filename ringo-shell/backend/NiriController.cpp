#include "NiriController.h"
#include <QDir>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDebug>
#include <unistd.h>

NiriController::NiriController(QObject *parent) : QObject(parent) {
    m_reconnectTimer.setInterval(3000);
    m_reconnectTimer.setSingleShot(false);
    connect(&m_reconnectTimer, &QTimer::timeout, this, &NiriController::connectToSocket);

    connectToSocket();
}

NiriController::~NiriController() {
    if (m_eventSocket) {
        m_eventSocket->disconnect(this);
        m_eventSocket->abort();
        delete m_eventSocket;
    }
    if (m_querySocket) {
        m_querySocket->disconnect(this);
        m_querySocket->abort();
        delete m_querySocket;
    }
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

void NiriController::connectToSocket() {
    m_socketPath = findNiriSocket();
    if (m_socketPath.isEmpty()) {
        if (!m_reconnectTimer.isActive()) m_reconnectTimer.start();
        return;
    }

    if (!m_eventSocket) {
        m_eventSocket = new QLocalSocket(this);
        connect(m_eventSocket, &QLocalSocket::readyRead, this, &NiriController::onEventSocketReadyRead);
        connect(m_eventSocket, &QLocalSocket::disconnected, this, &NiriController::onEventSocketDisconnected);
        connect(m_eventSocket, &QLocalSocket::connected, this, &NiriController::sendEventStreamRequest);
    }

    if (!m_querySocket) {
        m_querySocket = new QLocalSocket(this);
        connect(m_querySocket, &QLocalSocket::readyRead, this, &NiriController::onQuerySocketReadyRead);
    }

    if (m_eventSocket->state() == QLocalSocket::UnconnectedState) {
        m_eventSocket->connectToServer(m_socketPath);
    }

    if (m_querySocket->state() == QLocalSocket::UnconnectedState) {
        m_querySocket->connectToServer(m_socketPath);
    }
}

void NiriController::sendEventStreamRequest() {
    m_connected = true;
    emit connectionChanged();
    m_reconnectTimer.stop();

    if (m_eventSocket && m_eventSocket->isOpen()) {
        m_eventSocket->write("\"EventStream\"\n");
        m_eventSocket->flush();
    }

    queryWindows();
}

void NiriController::onEventSocketDisconnected() {
    m_connected = false;
    emit connectionChanged();
    if (!m_reconnectTimer.isActive()) {
        m_reconnectTimer.start();
    }
}

void NiriController::onEventSocketReadyRead() {
    if (!m_eventSocket) return;

    while (m_eventSocket->canReadLine()) {
        const QByteArray line = m_eventSocket->readLine().trimmed();
        if (line.isEmpty() || line.startsWith("{\"Ok\":\"Handled\"}")) continue;

        // Check if event affects window fullscreen or focus
        if (line.contains("WindowOpened") || line.contains("WindowClosed")
            || line.contains("WindowChanged") || line.contains("WindowFocusChanged")
            || line.contains("WorkspacesChanged") || line.contains("WorkspaceActivated")) {
            queryWindows();
        }
    }
}

void NiriController::queryWindows() {
    if (!m_querySocket) return;

    if (m_querySocket->state() != QLocalSocket::ConnectedState) {
        if (!m_socketPath.isEmpty()) {
            m_querySocket->connectToServer(m_socketPath);
            if (!m_querySocket->waitForConnected(200)) return;
        } else {
            return;
        }
    }

    m_queryBuffer.clear();
    m_querySocket->write("\"Windows\"\n");
    m_querySocket->flush();
}

void NiriController::onQuerySocketReadyRead() {
    if (!m_querySocket) return;
    m_queryBuffer.append(m_querySocket->readAll());

    // Niri sends JSON responses ending with newline
    if (m_queryBuffer.endsWith('\n')) {
        parseWindowsJson(m_queryBuffer.trimmed());
        m_queryBuffer.clear();
    }
}

void NiriController::parseWindowsJson(const QByteArray &data) {
    QJsonParseError err{};
    const QJsonDocument doc = QJsonDocument::fromJson(data, &err);
    if (err.error != QJsonParseError::NoError) return;

    QJsonArray windows;
    if (doc.isArray()) {
        windows = doc.array();
    } else if (doc.isObject()) {
        const QJsonObject obj = doc.object();
        if (obj.contains(QStringLiteral("Ok"))) {
            const QJsonObject okObj = obj.value(QStringLiteral("Ok")).toObject();
            if (okObj.contains(QStringLiteral("Windows"))) {
                windows = okObj.value(QStringLiteral("Windows")).toArray();
            }
        }
    }

    bool foundFullscreen = false;
    for (const QJsonValue &val : windows) {
        if (!val.isObject()) continue;
        const QJsonObject w = val.toObject();
        const bool isFocused = w.value(QStringLiteral("is_focused")).toBool();
        const bool isFullscreen = w.value(QStringLiteral("is_fullscreen")).toBool();

        if (isFocused && isFullscreen) {
            foundFullscreen = true;
            break;
        }
    }

    if (foundFullscreen != m_fullscreenActive) {
        m_fullscreenActive = foundFullscreen;
        emit fullscreenActiveChanged();
    }
}

void NiriController::refresh() {
    queryWindows();
}

void NiriController::action(const QString &actionName) {
    if (m_socketPath.isEmpty()) return;

    QLocalSocket sock;
    sock.connectToServer(m_socketPath);
    if (sock.waitForConnected(300)) {
        const QString cmd = QStringLiteral("{\"Action\":\"%1\"}\n").arg(actionName);
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
