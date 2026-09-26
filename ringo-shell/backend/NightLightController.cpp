#include "NightLightController.h"

#include "nightlight.h"

#include "StateStore.h"

#include <QElapsedTimer>
#include <QMetaObject>
#include <QTimer>

#include <functional>



namespace {
constexpr int kEngineWaitMs = 2000;
constexpr int kStopAttempts = 4;
constexpr int kEngineRestartDelayMs = 1000;
constexpr int kTwilightElevation = -6.0;
constexpr int kDaylightElevation = 3.0;

// A QThread must never be destroyed while it is still running: Qt treats that
// as fatal. Ask the engine to return, wait, and if it refuses, hand the object
// over to the event loop instead of deleting it here.
bool stopThread(QThread *thread, const std::function<void()> &requestStop) {
    for (int attempt = 0; attempt < kStopAttempts; ++attempt) {
        requestStop();
        if (thread->wait(kEngineWaitMs)) {
            thread->deleteLater();
            return true;
        }
    }

    QObject::connect(thread, &QThread::finished, thread, &QObject::deleteLater);
    thread->setParent(nullptr);
    return false;
}

// The engine blocks in its own Wayland event loop, so it needs a thread of its
// own; changing any option replaces the thread.
class NightLightThread final : public QThread {
public:
    NightLightThread(double latitude, double longitude, int lowTemperature,
                     int highTemperature, double gamma, int forced, QObject *parent)
        : QThread(parent)
        , m_latitude(latitude)
        , m_longitude(longitude)
        , m_lowTemperature(lowTemperature)
        , m_highTemperature(highTemperature)
        , m_gamma(gamma)
        , m_forced(forced) {}

    void run() override {
        struct ringo_nightlight_options options = {};
        options.latitude = m_latitude;
        options.longitude = m_longitude;
        options.low_temp = m_lowTemperature;
        options.high_temp = m_highTemperature;
        options.gamma = m_gamma;
        options.elevation_twilight = kTwilightElevation;
        options.elevation_daylight = kDaylightElevation;
        options.forced = m_forced;
        options.output_names = nullptr;
        options.manual_sunrise = -1;
        options.manual_sunset = -1;
        options.manual_duration = 0;

        if (ringo_nightlight_run(&options) != 0)
            m_error = QString::fromLocal8Bit(ringo_nightlight_error());
    }

    QString error() const { return m_error; }

private:
    double m_latitude;
    double m_longitude;
    int m_lowTemperature;
    int m_highTemperature;
    double m_gamma;
    int m_forced;
    QString m_error;
};

int forcedFromName(const QString &force) {
    if (force == QLatin1String("high")) return 1;
    if (force == QLatin1String("low")) return 2;
    return 0;
}
} // namespace

namespace {
const QString kEnabledKey = QStringLiteral("nightlight.enabled");
const QString kForceKey = QStringLiteral("nightlight.force");
} // namespace

NightLightController::NightLightController(QObject *parent) : QObject(parent) {
    // The toggles the UI changes are remembered; everything else is
    // configuration and lives in config.jsonc.
    m_enabled = StateStore::instance().get(kEnabledKey, true).toBool();
    const QString force = StateStore::instance().get(kForceKey).toString();
    if (force == QLatin1String("high") || force == QLatin1String("low")) m_force = force;
}

NightLightController::~NightLightController() {
    stopEngine();
}

void NightLightController::setActive(bool active) {
    if (m_active == active) return;
    m_active = active;
    emit activeChanged();
}

void NightLightController::setTemperature(int kelvin) {
    if (m_temperature == kelvin) return;
    m_temperature = kelvin;
    emit temperatureChanged();
}

void NightLightController::setOutputs(int outputs) {
    if (m_outputs == outputs) return;
    m_outputs = outputs;
    emit outputsChanged();
}

void NightLightController::setError(const QString &error) {
    if (m_error == error) return;
    m_error = error;
    emit errorChanged();
}

void NightLightController::setEnabled(bool enabled) {
    if (m_enabled == enabled) return;
    m_enabled = enabled;
    emit enabledChanged();
    StateStore::instance().set(kEnabledKey, enabled);
    if (enabled) {
        m_restarts = 0;
        startEngine();
    } else {
        stopEngine();
    }
}

void NightLightController::setLatitude(double latitude) {
    if (qFuzzyCompare(m_latitude + 1.0, latitude + 1.0) && m_locationExplicit) return;
    const bool moved = !qFuzzyCompare(m_latitude + 1.0, latitude + 1.0);
    m_latitude = latitude;
    if (!m_locationExplicit) {
        m_locationExplicit = true;
        emit locationExplicitChanged();
    }
    if (moved) emit latitudeChanged();
    restartEngine();
}

void NightLightController::setLongitude(double longitude) {
    if (qFuzzyCompare(m_longitude + 1.0, longitude + 1.0) && m_locationExplicit) return;
    const bool moved = !qFuzzyCompare(m_longitude + 1.0, longitude + 1.0);
    m_longitude = longitude;
    if (!m_locationExplicit) {
        m_locationExplicit = true;
        emit locationExplicitChanged();
    }
    if (moved) emit longitudeChanged();
    restartEngine();
}

void NightLightController::setAutoLocation(double latitude, double longitude) {
    if (m_locationExplicit) return;
    if (latitude == 0.0 && longitude == 0.0) return;
    if (qFuzzyCompare(m_latitude + 1.0, latitude + 1.0)
        && qFuzzyCompare(m_longitude + 1.0, longitude + 1.0)) {
        return;
    }

    m_latitude = latitude;
    m_longitude = longitude;
    emit latitudeChanged();
    emit longitudeChanged();
    restartEngine();
}

void NightLightController::clearLocationOverride() {
    if (!m_locationExplicit) return;
    m_locationExplicit = false;
    emit locationExplicitChanged();
}

void NightLightController::setLowTemperature(int kelvin) {
    if (m_lowTemperature == kelvin) return;
    m_lowTemperature = kelvin;
    emit lowTemperatureChanged();
    restartEngine();
}

void NightLightController::setHighTemperature(int kelvin) {
    if (m_highTemperature == kelvin) return;
    m_highTemperature = kelvin;
    emit highTemperatureChanged();
    restartEngine();
}

void NightLightController::setGamma(double gamma) {
    if (qFuzzyCompare(m_gamma + 1.0, gamma + 1.0)) return;
    m_gamma = gamma;
    emit gammaChanged();
    restartEngine();
}

void NightLightController::setForce(const QString &force) {
    const QString normalized = (force == QLatin1String("high") || force == QLatin1String("low"))
        ? force
        : QStringLiteral("off");
    if (m_force == normalized) return;
    m_force = normalized;
    emit forceChanged();
    StateStore::instance().set(kForceKey, normalized);
    restartEngine();
}

void NightLightController::start() {
    // Called at startup: the toggle the UI left behind is restored from the
    // state store, so this only has to bring the engine up.
    m_restarts = 0;
    if (!m_enabled) return;
    if (!m_engineThread) startEngine();
}

void NightLightController::stop() {
    setEnabled(false);
}

void NightLightController::reload() {
    m_restarts = 0;
    restartEngine();
}

void NightLightController::restartEngine() {
    if (!m_enabled) return;
    m_restarts = 0;
    startEngine();
}

void NightLightController::startEngine() {
    stopEngine(); // a replaced engine is not an unexpected exit

    ringo_nightlight_set_status_callback(&NightLightController::statusCallback, this);

    auto *thread = new NightLightThread(m_latitude, m_longitude, m_lowTemperature,
                                        m_highTemperature, m_gamma, forcedFromName(m_force), this);
    m_engineThread = thread;

    connect(thread, &QThread::started, this, [this, thread] {
        if (thread != m_engineThread) return;
        m_engineAlive.start();
        setError(QString());
    });
    connect(thread, &QThread::finished, this, [this, thread] { onEngineFinished(thread); });

    thread->start();
}

void NightLightController::onEngineFinished(QThread *thread) {
    if (thread != m_engineThread) {
        // A replaced engine: stopEngine() detached it before waking it, so this
        // exit is expected and must not touch the engine that replaced it.
        if (thread) thread->deleteLater();
        return;
    }

    const QString engineError =
        thread ? static_cast<NightLightThread *>(thread)->error() : QString();
    if (thread) thread->deleteLater();
    m_engineThread = nullptr;
    setActive(false);
    setOutputs(0);

    if (!m_enabled) return;

    // A compositor restart or a protocol error kills the engine; try once more
    // before reporting, so a transient failure does not leave the screen cold.
    if (m_restarts < 1) {
        m_restarts++;
        QTimer::singleShot(kEngineRestartDelayMs, this, [this] {
            if (!m_engineThread && m_enabled) startEngine();
        });
        return;
    }

    setError(engineError.isEmpty()
                 ? QStringLiteral("the night light engine stopped unexpectedly")
                 : QStringLiteral("the night light engine failed: %1").arg(engineError));
}

void NightLightController::stopEngine() {
    auto *thread = static_cast<NightLightThread *>(m_engineThread);
    if (!thread) return;

    // Detach first: the exit of a replaced engine is not an unexpected one, so
    // its finished handler must not run the supervision path.
    m_engineThread = nullptr;
    setActive(false);
    setOutputs(0);

    if (!stopThread(thread, [] { ringo_nightlight_stop(); })) {
        setError(QStringLiteral(
            "the night light engine did not stop; its thread is left to finish on its own"));
    }
}

void NightLightController::statusCallback(const struct ringo_nightlight_status *status,
                                          void *user) {
    auto *self = static_cast<NightLightController *>(user);
    if (self == nullptr) return;

    // Called from the engine thread; the engine reports on every ramp it sets.
    const int kelvin = status->temperature;
    const int outputs = status->outputs;
    QMetaObject::invokeMethod(
        self,
        [self, kelvin, outputs] {
            // A report from an engine that has already been replaced or stopped
            // must not resurrect `active`.
            if (!self->m_engineThread) return;
            self->setActive(true);
            self->setTemperature(kelvin);
            self->setOutputs(outputs);
            self->setError(outputs > 0
                               ? QString()
                               : QStringLiteral("no output accepted the gamma ramp "
                                                "(another gamma-control client may hold it)"));
        },
        Qt::QueuedConnection);
}
