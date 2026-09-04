#pragma once
#include <QObject>
#include <QtQml/qqml.h>
#include <pulse/pulseaudio.h>

class AudioController final : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QString activePort READ activePort NOTIFY activePortChanged)
    Q_PROPERTY(bool isHeadphone READ isHeadphone NOTIFY isHeadphoneChanged)
    Q_PROPERTY(QString sinkName READ sinkName NOTIFY sinkChanged)
    Q_PROPERTY(QString sinkDescription READ sinkDescription NOTIFY sinkChanged)

public:
    explicit AudioController(QObject *parent = nullptr);
    ~AudioController() override;

    QString activePort() const { return m_activePort; }
    bool isHeadphone() const { return m_isHeadphone; }
    QString sinkName() const { return m_sinkName; }
    QString sinkDescription() const { return m_sinkDescription; }

    Q_INVOKABLE void refresh();

signals:
    void activePortChanged();
    void isHeadphoneChanged();
    void sinkChanged();

private:
    void initPulse();
    void cleanupPulse();
    void onSinkInfo(const QString &sinkName, const QString &desc, const QString &portName, const QString &portDesc);

    static void contextStateCallback(pa_context *ctx, void *userdata);
    static void subscribeCallback(pa_context *ctx, pa_subscription_event_type_t type, uint32_t idx, void *userdata);
    static void serverInfoCallback(pa_context *ctx, const pa_server_info *info, void *userdata);
    static void sinkInfoCallback(pa_context *ctx, const pa_sink_info *info, int eol, void *userdata);

    pa_threaded_mainloop *m_mainloop = nullptr;
    pa_context *m_context = nullptr;

    QString m_activePort;
    bool m_isHeadphone = false;
    QString m_sinkName;
    QString m_sinkDescription;
};
