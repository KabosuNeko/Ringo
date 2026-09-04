#include "AudioController.h"
#include <QMetaObject>
#include <QDebug>

AudioController::AudioController(QObject *parent) : QObject(parent) {
    initPulse();
}

AudioController::~AudioController() {
    cleanupPulse();
}

void AudioController::initPulse() {
    m_mainloop = pa_threaded_mainloop_new();
    if (!m_mainloop) return;

    pa_mainloop_api *api = pa_threaded_mainloop_get_api(m_mainloop);
    m_context = pa_context_new(api, "IslandAudioController");
    if (!m_context) {
        pa_threaded_mainloop_free(m_mainloop);
        m_mainloop = nullptr;
        return;
    }

    pa_context_set_state_callback(m_context, contextStateCallback, this);
    pa_context_set_subscribe_callback(m_context, subscribeCallback, this);

    if (pa_threaded_mainloop_start(m_mainloop) < 0) {
        cleanupPulse();
        return;
    }

    pa_threaded_mainloop_lock(m_mainloop);
    pa_context_connect(m_context, nullptr, PA_CONTEXT_NOFLAGS, nullptr);
    pa_threaded_mainloop_unlock(m_mainloop);
}

void AudioController::cleanupPulse() {
    if (m_mainloop) {
        pa_threaded_mainloop_stop(m_mainloop);
    }
    if (m_context) {
        pa_context_disconnect(m_context);
        pa_context_unref(m_context);
        m_context = nullptr;
    }
    if (m_mainloop) {
        pa_threaded_mainloop_free(m_mainloop);
        m_mainloop = nullptr;
    }
}

void AudioController::contextStateCallback(pa_context *ctx, void *userdata) {
    auto *self = static_cast<AudioController *>(userdata);
    const pa_context_state_t state = pa_context_get_state(ctx);

    if (state == PA_CONTEXT_READY) {
        pa_context_subscribe(ctx, static_cast<pa_subscription_mask_t>(
            PA_SUBSCRIPTION_MASK_SINK | PA_SUBSCRIPTION_MASK_SERVER), nullptr, nullptr);
        pa_context_get_server_info(ctx, serverInfoCallback, self);
    }
}

void AudioController::subscribeCallback(pa_context *ctx, pa_subscription_event_type_t type, uint32_t /*idx*/, void *userdata) {
    auto *self = static_cast<AudioController *>(userdata);
    const int facility = type & PA_SUBSCRIPTION_EVENT_FACILITY_MASK;

    if (facility == PA_SUBSCRIPTION_EVENT_SINK || facility == PA_SUBSCRIPTION_EVENT_SERVER) {
        pa_context_get_server_info(ctx, serverInfoCallback, self);
    }
}

void AudioController::serverInfoCallback(pa_context *ctx, const pa_server_info *info, void *userdata) {
    if (!info || !info->default_sink_name) return;
    auto *self = static_cast<AudioController *>(userdata);
    pa_context_get_sink_info_by_name(ctx, info->default_sink_name, sinkInfoCallback, self);
}

void AudioController::sinkInfoCallback(pa_context * /*ctx*/, const pa_sink_info *info, int eol, void *userdata) {
    if (eol > 0 || !info) return;
    auto *self = static_cast<AudioController *>(userdata);

    const QString sinkName = QString::fromUtf8(info->name ? info->name : "");
    const QString desc = QString::fromUtf8(info->description ? info->description : "");
    QString portName;
    QString portDesc;

    if (info->active_port) {
        if (info->active_port->name) portName = QString::fromUtf8(info->active_port->name);
        if (info->active_port->description) portDesc = QString::fromUtf8(info->active_port->description);
    }

    self->onSinkInfo(sinkName, desc, portName, portDesc);
}

void AudioController::onSinkInfo(const QString &sinkName, const QString &desc, const QString &portName, const QString &portDesc) {
    // Thread safety: dispatch back to Qt main event loop
    QMetaObject::invokeMethod(this, [this, sinkName, desc, portName, portDesc]() {
        if (m_sinkName != sinkName || m_sinkDescription != desc) {
            m_sinkName = sinkName;
            m_sinkDescription = desc;
            emit sinkChanged();
        }

        if (m_activePort != portName) {
            m_activePort = portName;
            emit activePortChanged();
        }

        const bool headphone = portName.contains(QStringLiteral("headphone"), Qt::CaseInsensitive)
            || portName.contains(QStringLiteral("headset"), Qt::CaseInsensitive)
            || portDesc.contains(QStringLiteral("headphone"), Qt::CaseInsensitive)
            || portDesc.contains(QStringLiteral("headset"), Qt::CaseInsensitive)
            || desc.contains(QStringLiteral("headphone"), Qt::CaseInsensitive)
            || desc.contains(QStringLiteral("headset"), Qt::CaseInsensitive);

        if (m_isHeadphone != headphone) {
            m_isHeadphone = headphone;
            emit isHeadphoneChanged();
        }
    }, Qt::QueuedConnection);
}

void AudioController::refresh() {
    if (!m_mainloop || !m_context) return;
    pa_threaded_mainloop_lock(m_mainloop);
    if (pa_context_get_state(m_context) == PA_CONTEXT_READY) {
        pa_context_get_server_info(m_context, serverInfoCallback, this);
    }
    pa_threaded_mainloop_unlock(m_mainloop);
}
