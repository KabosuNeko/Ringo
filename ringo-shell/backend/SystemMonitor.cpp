#include "SystemMonitor.h"
#include <QFile>
#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusReply>
#include <QNetworkInterface>
#include <QVariantMap>
#include <cmath>
#include <algorithm>

SystemMonitor::SystemMonitor(QObject *parent) : QObject(parent) {
    m_telemetryTimer.setInterval(1000);
    m_telemetryTimer.setSingleShot(false);
    connect(&m_telemetryTimer, &QTimer::timeout, this, &SystemMonitor::pollTelemetry);

    // Network and uptime only feed the mini dashboard, so they share the
    // telemetry timer's lifetime (see setTelemetryActive).
    m_netTimer.setInterval(30000);
    m_netTimer.setSingleShot(false);
    connect(&m_netTimer, &QTimer::timeout, this, &SystemMonitor::pollNetwork);

    m_uptimeTimer.setInterval(60000);
    m_uptimeTimer.setSingleShot(false);
    connect(&m_uptimeTimer, &QTimer::timeout, this, &SystemMonitor::pollUptime);

    // UPower PropertiesChanged fires reliably on this object, so there is no
    // polling timer; the bar is fed by this signal plus the initial read below.
    QDBusConnection::systemBus().connect(
        QStringLiteral("org.freedesktop.UPower"),
        QStringLiteral("/org/freedesktop/UPower/devices/DisplayDevice"),
        QStringLiteral("org.freedesktop.DBus.Properties"),
        QStringLiteral("PropertiesChanged"),
        this, SLOT(handleUPowerPropertiesChanged(QString,QVariantMap,QStringList)));

    // One read so the bar has a value before the first signal.
    pollBattery();
}

void SystemMonitor::setTelemetryActive(bool active) {
    if (m_telemetryActive == active) return;
    m_telemetryActive = active;
    emit telemetryActiveChanged();

    if (m_telemetryActive) {
        // Immediate sampling so the dashboard is populated on open.
        pollRam();
        pollBandwidth();
        pollCpu();
        pollNetwork();
        pollUptime();
        m_telemetryTimer.start();
        m_netTimer.start();
        m_uptimeTimer.start();
    } else {
        m_telemetryTimer.stop();
        m_netTimer.stop();
        m_uptimeTimer.stop();
        m_prevRx = -1;
        m_prevTx = -1;
        m_prevCpuTotal = 0;
        m_prevCpuIdle = 0;
        setRxRate(QStringLiteral("0 B/s"));
        setTxRate(QStringLiteral("0 B/s"));
    }
}

void SystemMonitor::pollTelemetry() {
    pollBandwidth();
    pollCpu();
    pollRam();
}

QString SystemMonitor::fmtRate(double bps) {
    if (!std::isfinite(bps) || bps < 0) return QStringLiteral("...");
    if (bps < 1024) return QString::number(qRound(bps)) + QStringLiteral(" B/s");
    if (bps < 1048576) return QString::number(bps / 1024.0, 'f', 1) + QStringLiteral(" KB/s");
    return QString::number(bps / 1048576.0, 'f', 1) + QStringLiteral(" MB/s");
}

QString SystemMonitor::fmtUptime(double seconds) {
    if (!std::isfinite(seconds) || seconds < 0) return QStringLiteral("...");
    int s = int(seconds);
    int d = s / 86400; s %= 86400;
    int h = s / 3600; s %= 3600;
    int m = s / 60;
    if (d > 0) return QString::number(d) + QStringLiteral("d ") + QString::number(h) + QStringLiteral("h");
    if (h > 0) return QString::number(h) + QStringLiteral("h ") + QString::number(m) + QStringLiteral("m");
    return QString::number(m) + QStringLiteral("m");
}

void SystemMonitor::setRxRate(const QString &v) { if (m_rxRate==v) return; m_rxRate=v; emit rxRateChanged(); }
void SystemMonitor::setTxRate(const QString &v) { if (m_txRate==v) return; m_txRate=v; emit txRateChanged(); }
void SystemMonitor::setIp(const QString &v) { if (m_ip==v) return; m_ip=v; emit ipChanged(); }
void SystemMonitor::setIface(const QString &v) { if (m_iface==v) return; m_iface=v; emit ifaceChanged(); }
void SystemMonitor::setVpn(bool v) { if (m_vpn==v) return; m_vpn=v; emit vpnChanged(); }
void SystemMonitor::setHasBattery(bool v) { if (m_hasBattery==v) return; m_hasBattery=v; emit hasBatteryChanged(); }
void SystemMonitor::setBatteryPercentage(int v) { if (m_batteryPercentage==v) return; m_batteryPercentage=v; emit batteryPercentageChanged(); }
void SystemMonitor::setCharging(bool v) { if (m_charging==v) return; m_charging=v; emit chargingChanged(); }
void SystemMonitor::setUptime(const QString &v) { if (m_uptime==v) return; m_uptime=v; emit uptimeChanged(); }

void SystemMonitor::pollBandwidth() {
    QFile f(QStringLiteral("/proc/net/dev"));
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return;
    // skip 2 header lines
    f.readLine(); f.readLine();
    qint64 totalRx = 0, totalTx = 0;
    while (!f.atEnd()) {
        const QByteArray line = f.readLine();
        int colon = line.indexOf(':');
        if (colon < 0) continue;
        // skip loopback
        QByteArray iface = line.left(colon).trimmed();
        if (iface == "lo") continue;
        // fields after colon: rx_bytes ... (8th field) tx_bytes
        const char *p = line.constData() + colon + 1;
        qint64 vals[10];
        int n = 0;
        while (*p && n < 10) {
            while (*p == ' ' || *p == '\t') ++p;
            if (!*p || *p == '\n') break;
            qint64 v = 0;
            while (*p >= '0' && *p <= '9') { v = v * 10 + (*p - '0'); ++p; }
            vals[n++] = v;
        }
        if (n >= 10) { totalRx += vals[0]; totalTx += vals[8]; }
    }
    double rx = double(totalRx);
    double tx = double(totalTx);
    if (m_prevRx < 0) {
        m_prevRx = rx; m_prevTx = tx;
        setRxRate(fmtRate(0));
        setTxRate(fmtRate(0));
        return;
    }
    double dRx = rx - m_prevRx; if (dRx < 0) dRx = 0;
    double dTx = tx - m_prevTx; if (dTx < 0) dTx = 0;
    m_prevRx = rx; m_prevTx = tx;
    setRxRate(fmtRate(dRx));
    setTxRate(fmtRate(dTx));
}

void SystemMonitor::pollCpu() {
    QFile f(QStringLiteral("/proc/stat"));
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return;
    QByteArray line = f.readLine();
    if (!line.startsWith("cpu ")) return;

    const char *p = line.constData() + 4; // skip "cpu "
    quint64 vals[8] = {};
    int n = 0;
    while (*p && n < 8) {
        while (*p == ' ') ++p;
        if (!*p || *p == '\n') break;
        quint64 v = 0;
        while (*p >= '0' && *p <= '9') { v = v * 10 + (*p - '0'); ++p; }
        vals[n++] = v;
    }
    if (n < 4) return;
    // user nice system idle iowait irq softirq steal
    quint64 total = 0;
    for (int i = 0; i < n; ++i) total += vals[i];
    quint64 idleAll = vals[3] + (n > 4 ? vals[4] : 0);

    if (m_prevCpuTotal > 0 && total > m_prevCpuTotal) {
        quint64 dTotal = total - m_prevCpuTotal;
        quint64 dIdle = idleAll > m_prevCpuIdle ? (idleAll - m_prevCpuIdle) : 0;
        int usage = std::clamp(static_cast<int>(std::round(100.0 * (1.0 - double(dIdle) / double(dTotal)))), 0, 100);
        if (m_cpuPercent != usage) {
            m_cpuPercent = usage;
            emit cpuPercentChanged();
        }
    }
    m_prevCpuTotal = total;
    m_prevCpuIdle = idleAll;
}

void SystemMonitor::pollRam() {
    QFile f(QStringLiteral("/proc/meminfo"));
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return;
    quint64 memTotal = 0;
    quint64 memAvailable = 0;
    int found = 0;
    while (found < 2) {
        QByteArray line = f.readLine();
        if (line.isEmpty()) break;
        if (line.startsWith("MemTotal:")) {
            const auto parts = line.simplified().split(' ');
            if (parts.size() >= 2) {
                memTotal = parts[1].toULongLong();
                found++;
            }
        } else if (line.startsWith("MemAvailable:")) {
            const auto parts = line.simplified().split(' ');
            if (parts.size() >= 2) {
                memAvailable = parts[1].toULongLong();
                found++;
            }
        }
    }
    if (memTotal > 0) {
        quint64 memUsed = (memTotal > memAvailable) ? (memTotal - memAvailable) : 0;
        int pct = std::clamp(static_cast<int>(std::round(100.0 * double(memUsed) / double(memTotal))), 0, 100);
        if (m_ramPercent != pct) {
            m_ramPercent = pct;
            emit ramPercentChanged();
        }
    }
}

void SystemMonitor::pollNetwork() {
    QString defaultIface;
    {
        QFile f(QStringLiteral("/proc/net/route"));
        if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            f.readLine(); // header
            while (!f.atEnd()) {
                const QByteArray line = f.readLine();
                // fields are tab-separated: iface destination ...
                int tab1 = line.indexOf('\t');
                if (tab1 < 0) continue;
                int tab2 = line.indexOf('\t', tab1 + 1);
                if (tab2 < 0) continue;
                QByteArray dest = line.mid(tab1 + 1, tab2 - tab1 - 1).trimmed();
                if (dest == "00000000") {
                    defaultIface = QString::fromLatin1(line.left(tab1).trimmed());
                    break;
                }
            }
        }
    }
    QString ipStr = QStringLiteral("unknown");
    QString ifaceStr = defaultIface.isEmpty() ? QStringLiteral("unknown") : defaultIface;
    bool vpn = false;
    const auto ifaces = QNetworkInterface::allInterfaces();
    for (const auto &iface : ifaces) {
        QString name = iface.name();
        if (name.startsWith(QStringLiteral("tun")) || name.startsWith(QStringLiteral("wg")) || name.contains(QStringLiteral("proton"))) {
            if (iface.flags().testFlag(QNetworkInterface::IsUp)) vpn = true;
        }
        if (!defaultIface.isEmpty() && name == defaultIface) {
            for (const auto &entry : iface.addressEntries()) {
                auto ip = entry.ip();
                if (ip.protocol() == QAbstractSocket::IPv4Protocol && !ip.isLoopback()) {
                    ipStr = ip.toString();
                    break;
                }
            }
        }
    }
    if (ipStr == QStringLiteral("unknown")) {
        for (const auto &iface : ifaces) {
            if (iface.flags().testFlag(QNetworkInterface::IsUp) && !iface.flags().testFlag(QNetworkInterface::IsLoopBack)) {
                for (const auto &entry : iface.addressEntries()) {
                    auto ip = entry.ip();
                    if (ip.protocol() == QAbstractSocket::IPv4Protocol && !ip.isLoopback()) {
                        ipStr = ip.toString();
                        if (ifaceStr == QStringLiteral("unknown")) ifaceStr = iface.name();
                        break;
                    }
                }
                if (ipStr != QStringLiteral("unknown")) break;
            }
        }
    }
    setIp(ipStr);
    setIface(ifaceStr);
    setVpn(vpn);
}

void SystemMonitor::pollUptime() {
    QFile f(QStringLiteral("/proc/uptime"));
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return;
    QByteArray data = f.readAll();
    double secs = data.split(' ')[0].toDouble();
    setUptime(fmtUptime(secs));
}

void SystemMonitor::pollBattery() {
    const QString upower = QStringLiteral("org.freedesktop.UPower");
    auto readBattery = [&](const QString &path) -> bool {
        QDBusInterface battery(upower, path,
                               QStringLiteral("org.freedesktop.DBus.Properties"),
                               QDBusConnection::systemBus());
        QDBusReply<QVariant> presentReply = battery.call(
            QStringLiteral("Get"), QStringLiteral("org.freedesktop.UPower.Device"),
            QStringLiteral("IsPresent"));
        if (presentReply.isValid() && !presentReply.value().toBool()) return false;
        QDBusReply<QVariant> pctReply = battery.call(
            QStringLiteral("Get"), QStringLiteral("org.freedesktop.UPower.Device"),
            QStringLiteral("Percentage"));
        if (!pctReply.isValid()) return false;
        QDBusReply<QVariant> stateReply = battery.call(
            QStringLiteral("Get"), QStringLiteral("org.freedesktop.UPower.Device"),
            QStringLiteral("State"));
        const uint state = stateReply.isValid() ? stateReply.value().toUInt() : 2;
        setHasBattery(true);
        setBatteryPercentage(int(std::round(pctReply.value().toDouble())));
        setCharging(state == 1 || state == 4);
        updateBatteryIcon();
        return true;
    };

    const QString displayPath = QStringLiteral("/org/freedesktop/UPower/devices/DisplayDevice");
    if (readBattery(displayPath)) return;

    // DisplayDevice can be absent on some UPower setups. Enumerate the real
    // battery objects instead of assuming BAT0 (this laptop is BAT1).
    QDBusMessage request = QDBusMessage::createMethodCall(
        upower, QStringLiteral("/org/freedesktop/UPower"),
        QStringLiteral("org.freedesktop.UPower"), QStringLiteral("EnumerateDevices"));
    const QDBusMessage reply = QDBusConnection::systemBus().call(request);
    QList<QDBusObjectPath> paths;
    if (reply.type() != QDBusMessage::ErrorMessage && !reply.arguments().isEmpty()) {
        const QVariant arg = reply.arguments().constFirst();
        if (arg.userType() == qMetaTypeId<QDBusArgument>())
            paths = qdbus_cast<QList<QDBusObjectPath>>(qvariant_cast<QDBusArgument>(arg));
        else
            paths = arg.value<QList<QDBusObjectPath>>();
    }
    for (const QDBusObjectPath &path : paths) {
        if (!path.path().contains(QStringLiteral("battery"))) continue;
        if (readBattery(path.path())) return;
    }
    setHasBattery(false);
}

void SystemMonitor::handleUPowerPropertiesChanged(const QString &interface, const QVariantMap &changed, const QStringList &) {
    if (interface != QStringLiteral("org.freedesktop.UPower.Device")) return;
    if (changed.contains(QStringLiteral("Percentage"))) setBatteryPercentage(int(std::round(changed.value(QStringLiteral("Percentage")).toDouble())));
    if (changed.contains(QStringLiteral("State"))) {
        uint s = changed.value(QStringLiteral("State")).toUInt();
        setCharging(s == 1 || s == 4);
    }
    if (changed.contains(QStringLiteral("Percentage")) || changed.contains(QStringLiteral("State")))
        updateBatteryIcon();
    if (changed.contains(QStringLiteral("IsPresent"))) {
        bool p = changed.value(QStringLiteral("IsPresent")).toBool();
        setHasBattery(p);
    }
}

void SystemMonitor::updateBatteryIcon() {
    QString icon;
    if (!m_hasBattery) { icon = QStringLiteral("󰂃"); }
    else if (m_charging) { icon = QStringLiteral("󰂄"); }
    else {
        int p = m_batteryPercentage;
        if (p >= 90) icon = QStringLiteral("󰁹");
        else if (p >= 80) icon = QStringLiteral("󰂂");
        else if (p >= 60) icon = QStringLiteral("󰂀");
        else if (p >= 40) icon = QStringLiteral("󰁿");
        else if (p >= 20) icon = QStringLiteral("󰁽");
        else if (p >= 10) icon = QStringLiteral("󰁻");
        else icon = QStringLiteral("󰂃");
    }
    if (m_batteryIcon != icon) { m_batteryIcon = icon; emit batteryIconChanged(); }
}
