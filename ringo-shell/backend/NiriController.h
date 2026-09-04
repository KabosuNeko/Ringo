#pragma once
#include <QObject>
#include <QLocalSocket>
#include <QTimer>
#include <QtQml/qqml.h>

class NiriController final : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool fullscreenActive READ fullscreenActive NOTIFY fullscreenActiveChanged)
    Q_PROPERTY(bool connected READ isConnected NOTIFY connectionChanged)

public:
    explicit NiriController(QObject *parent = nullptr);
    ~NiriController() override;

    bool fullscreenActive() const { return m_fullscreenActive; }
    bool isConnected() const { return m_connected; }

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void action(const QString &actionName);
    Q_INVOKABLE void quit();
    Q_INVOKABLE void powerOffMonitors();
    Q_INVOKABLE void powerOnMonitors();
    Q_INVOKABLE void suspend();
    Q_INVOKABLE void reboot();
    Q_INVOKABLE void powerOff();

signals:
    void fullscreenActiveChanged();
    void connectionChanged();

private slots:
    void connectToSocket();
    void onEventSocketReadyRead();
    void onEventSocketDisconnected();
    void onQuerySocketReadyRead();

private:
    void sendEventStreamRequest();
    void queryWindows();
    void parseWindowsJson(const QByteArray &data);
    QString findNiriSocket();

    QString m_socketPath;
    QLocalSocket *m_eventSocket = nullptr;
    QLocalSocket *m_querySocket = nullptr;
    QByteArray m_queryBuffer;
    bool m_connected = false;
    bool m_fullscreenActive = false;
    QTimer m_reconnectTimer;
};
