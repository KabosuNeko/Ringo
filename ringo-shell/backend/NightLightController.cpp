#include "NightLightController.h"

#include "StateStore.h"

#include <QStandardPaths>
#include <QStringList>

#include <csignal>
#include <unistd.h>
#ifdef Q_OS_LINUX
#include <sys/prctl.h>
#endif

namespace {
const QString kBinary = QStringLiteral("wlsunset");
const QString kEnabledKey = QStringLiteral("nightlight.enabled");
const QString kForceKey = QStringLiteral("nightlight.force");
constexpr int kRestartDelayMs = 1000;
constexpr int kTerminateWaitMs = 500;
constexpr int kHealthyRunMs = 60000;

// wlsunset cycles its manual override on SIGUSR1: off -> high -> low -> off.
int forceIndex(const QString &force) {
    if (force == QLatin1String("high")) return 1;
    if (force == QLatin1String("low")) return 2;
    return 0;
}
} // namespace

NightLightController::NightLightController(QObject *parent) : QObject(parent) {
    // Only the UI toggles persist; everything else is config.jsonc's job.
    m_enabled = StateStore::instance().get(kEnabledKey, true).toBool();
    const QString force = StateStore::instance().get(kForceKey).toString();
    if (force == QLatin1String("high") || force == QLatin1String("low")) m_force = force;

    m_process.setReadChannel(QProcess::StandardError);

    m_restartTimer.setSingleShot(true);
    m_restartTimer.setInterval(kRestartDelayMs);
    connect(&m_restartTimer, &QTimer::timeout, this, [this] {
        if (m_enabled) startEngine();
    });

    // terminate() is asynchronous; give wlsunset a moment to exit, then kill.
    m_stopTimer.setSingleShot(true);
    m_stopTimer.setInterval(kTerminateWaitMs);
    connect(&m_stopTimer, &QTimer::timeout, this, [this] {
        if (m_process.state() != QProcess::NotRunning) m_process.kill();
    });

    connect(&m_process, &QProcess::readyReadStandardError, this, &NightLightController::readEngineOutput);
    connect(&m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) {
            setActive(false);
            setError(QStringLiteral("could not start %1 (install it with: pacman -S %1)").arg(kBinary));
        }
    });
    connect(&m_process, &QProcess::finished, this, [this](int code, QProcess::ExitStatus status) {
        m_stopTimer.stop();
        setActive(false);
        setTemperature(0);
        m_forceSignalPending = false;

        const bool wasStopping = m_stopping;
        m_stopping = false;

        if (m_restartPending) {
            m_restartPending = false;
            if (m_enabled) startEngine();
            return;
        }
        if (wasStopping || !m_enabled) return;

        if (m_uptime.isValid() && m_uptime.elapsed() > kHealthyRunMs) m_restarts = 0;

        // Compositor restart or killed process: retry once before reporting.
        if (m_restarts < 1) {
            m_restarts++;
            m_restartTimer.start();
            return;
        }
        setError(status == QProcess::CrashExit
                     ? QStringLiteral("%1 crashed (signal)").arg(kBinary)
                     : QStringLiteral("%1 exited with code %2").arg(kBinary).arg(code));
    });
}

NightLightController::~NightLightController() {
    stopEngineBlocking();
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

void NightLightController::setError(const QString &error) {
    if (m_error == error) return;
    m_error = error;
    emit errorChanged();
}

void NightLightController::setForceInternal(const QString &force) {
    if (m_appliedForce == force) return;
    m_appliedForce = force;
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
        m_restartPending = false;
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
    applyForce();
}

void NightLightController::start() {
    m_restarts = 0;
    if (!m_enabled) return;
    if (m_process.state() == QProcess::NotRunning) startEngine();
}

void NightLightController::restartEngine() {
    if (!m_enabled) return;
    m_restarts = 0;
    startEngine();
}

void NightLightController::startEngine() {
    if (m_process.state() != QProcess::NotRunning || m_stopping) {
        // A previous stop is still in flight; start again from its finished
        // handler instead of calling QProcess::start() on a running process.
        m_restartPending = true;
        stopEngine();
        return;
    }
    m_restartPending = false;

    // Some builds install it in /usr/sbin, which a session PATH lacks.
    const QString binary = QStandardPaths::findExecutable(
        kBinary, {QStringLiteral("/usr/local/bin"), QStringLiteral("/usr/bin"), QStringLiteral("/usr/sbin")});
    if (binary.isEmpty()) {
        setError(QStringLiteral("%1 is not installed (pacman -S %1)").arg(kBinary));
        return;
    }

    QStringList args;
    args << "-t" << QString::number(m_lowTemperature)
         << "-T" << QString::number(m_highTemperature)
         << "-g" << QString::number(m_gamma, 'f', 3)
         << "-l" << QString::number(m_latitude, 'f', 4)
         << "-L" << QString::number(m_longitude, 'f', 4);

    m_stopping = false;
    m_appliedForce = QStringLiteral("off"); // a fresh process starts unforced
    m_forceSignalPending = false;
    m_gammaRetryUsed = false;
    // Without this a shell restart leaves the old client holding the outputs.
#ifdef Q_OS_LINUX
    m_process.setChildProcessModifier([] { prctl(PR_SET_PDEATHSIG, SIGTERM); });
#endif
    m_process.setProgram(binary);
    m_process.setArguments(args);
    m_process.start();
    m_uptime.start();
}

void NightLightController::stopEngine() {
    if (m_process.state() == QProcess::NotRunning) {
        setActive(false);
        setTemperature(0);
        return;
    }

    // Do not wait on the GUI thread: terminate, then kill from m_stopTimer if
    // the process ignores SIGTERM. The finished handler does the cleanup.
    m_stopping = true;
    m_forceSignalPending = false;
    m_process.terminate();
    m_stopTimer.start();
}

void NightLightController::stopEngineBlocking() {
    // Destructor path: there is no event loop left to run m_stopTimer.
    m_restartPending = false;
    m_stopping = true;
    m_stopTimer.stop();
    if (m_process.state() != QProcess::NotRunning) {
        m_process.terminate();
        if (!m_process.waitForFinished(kTerminateWaitMs)) {
            m_process.kill();
            m_process.waitForFinished(kTerminateWaitMs);
        }
    }
    m_stopping = false;
    m_forceSignalPending = false;
    setActive(false);
    setTemperature(0);
}

void NightLightController::applyForce() {
    // The first "setting temperature" line proves wlsunset installed its
    // SIGUSR1 handler; sending the signal before that would kill it.
    if (!m_active || m_process.state() != QProcess::Running) return;

    const int steps = (forceIndex(m_force) - forceIndex(m_appliedForce) + 3) % 3;
    if (steps == 0) {
        m_forceSignalPending = false;
        return;
    }
    // wlsunset cycles one step per SIGUSR1 and prints the new state. Sending
    // the next signal only after that line is read keeps standard signals
    // from coalescing, which used to land on the wrong force state.
    if (m_forceSignalPending) return;
    m_forceSignalPending = true;
    if (::kill(static_cast<pid_t>(m_process.processId()), SIGUSR1) != 0) {
        m_forceSignalPending = false;
    }
}

void NightLightController::readEngineOutput() {
    while (m_process.canReadLine()) {
        const QString line = QString::fromLocal8Bit(m_process.readLine()).trimmed();
        if (line.isEmpty()) continue;

        const QString temperaturePrefix = QStringLiteral("setting temperature to ");
        if (line.startsWith(temperaturePrefix)) {
            const QString kelvin = line.mid(temperaturePrefix.size()).section(QLatin1Char(' '), 0, 0);
            bool ok = false;
            const int value = kelvin.toInt(&ok);
            if (ok) {
                setTemperature(value);
                setActive(true);
                setError(QString());
                // SIGUSR1 before the handler is installed would kill wlsunset.
                if (m_force != m_appliedForce) applyForce();
            }
            continue;
        }

        if (line.startsWith(QLatin1String("forcing high temperature"))) {
            setForceInternal(QStringLiteral("high"));
            m_forceSignalPending = false;
            applyForce();
            continue;
        }
        if (line.startsWith(QLatin1String("forcing low temperature"))) {
            setForceInternal(QStringLiteral("low"));
            m_forceSignalPending = false;
            applyForce();
            continue;
        }
        if (line.startsWith(QLatin1String("disabling forced temperature"))) {
            setForceInternal(QStringLiteral("off"));
            m_forceSignalPending = false;
            applyForce();
            continue;
        }


        if (line.contains(QLatin1String("failed")) || line.contains(QLatin1String("could not"))
            || line.contains(QLatin1String("must be"))) {
            setError(line);
            // A held output (previous wlsunset during a QML reload) clears by
            // itself: restart once.
            if (line.contains(QLatin1String("gamma control"))
                && line.contains(QLatin1String("failed")) && !m_gammaRetryUsed) {
                m_gammaRetryUsed = true;
                m_restartTimer.start();
            }
        }
    }
}
