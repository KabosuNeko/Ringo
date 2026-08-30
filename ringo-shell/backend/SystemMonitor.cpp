#include "SystemMonitor.h"
#include <QFile>
#include <QTextStream>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDebug>
#include <QStandardPaths>
#include <QVariantMap>
#include <QRegularExpression>
#include <cmath>

namespace {
QString readFile(const QString &path) {
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return {};
    return QString::fromUtf8(f.readAll());
}
}

SystemMonitor::SystemMonitor(QObject *parent) : QObject(parent) {
    m_bwTimer.setInterval(1000);
    m_bwTimer.setSingleShot(false);
    connect(&m_bwTimer, &QTimer::timeout, this, &SystemMonitor::pollBandwidth);

    m_netTimer.setInterval(30000);
    m_netTimer.setSingleShot(false);
    connect(&m_netTimer, &QTimer::timeout, this, &SystemMonitor::pollNetwork);

    m_uptimeTimer.setInterval(60000);
    m_uptimeTimer.setSingleShot(false);
    connect(&m_uptimeTimer, &QTimer::timeout, this, &SystemMonitor::pollUptime);

    m_batTimer.setInterval(30000);
    m_batTimer.setSingleShot(false);
    connect(&m_batTimer, &QTimer::timeout, this, &SystemMonitor::pollBattery);

    // UPower DBus PropertiesChanged
    QDBusConnection::systemBus().connect(
        QStringLiteral("org.freedesktop.UPower"),
        QStringLiteral("/org/freedesktop/UPower/devices/DisplayDevice"),
        QStringLiteral("org.freedesktop.DBus.Properties"),
        QStringLiteral("PropertiesChanged"),
        this, SLOT(handleUPowerPropertiesChanged(QString,QVariantMap,QStringList)));

    // initial poll
    pollBandwidth();
    pollNetwork();
    pollUptime();
    pollBattery();

    m_bwTimer.start();
    m_netTimer.start();
    m_uptimeTimer.start();
    m_batTimer.start();
}

void SystemMonitor::refresh() { pollBandwidth(); pollNetwork(); pollUptime(); pollBattery(); }
void SystemMonitor::refreshBandwidth() { pollBandwidth(); }
void SystemMonitor::refreshNetwork() { pollNetwork(); }
void SystemMonitor::refreshBattery() { pollBattery(); }
void SystemMonitor::refreshUptime() { pollUptime(); }

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
    QTextStream in(&f);
    QString line;
    // skip 2 header lines
    in.readLine(); in.readLine();
    qint64 totalRx = 0, totalTx = 0;
    while (!in.atEnd()) {
        line = in.readLine().trimmed();
        if (line.isEmpty()) continue;
        int colon = line.indexOf(':');
        if (colon < 0) continue;
        QString iface = line.left(colon).trimmed();
        if (iface == QStringLiteral("lo")) continue;
        QString rest = line.mid(colon+1).trimmed();
        QStringList parts = rest.split(QRegularExpression(QStringLiteral("\\s+")), Qt::SkipEmptyParts);
        if (parts.size() < 10) continue;
        bool ok1=false, ok2=false;
        qint64 rx = parts[0].toLongLong(&ok1);
        qint64 tx = parts[8].toLongLong(&ok2);
        if (!ok1 || !ok2) continue;
        totalRx += rx;
        totalTx += tx;
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

void SystemMonitor::pollNetwork() {
    // default route iface from /proc/net/route
    QString defaultIface;
    {
        QFile f(QStringLiteral("/proc/net/route"));
        if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QTextStream in(&f);
            in.readLine(); // header
            while (!in.atEnd()) {
                QString l = in.readLine();
                QStringList p = l.split(QRegularExpression(QStringLiteral("\\s+")), Qt::SkipEmptyParts);
                if (p.size() >= 2 && p[1] == QStringLiteral("00000000")) { defaultIface = p[0]; break; }
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
    // fallback: if defaultIface empty, try first non-loopback ipv4
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
    QDBusInterface iface(QStringLiteral("org.freedesktop.UPower"),
                         QStringLiteral("/org/freedesktop/UPower/devices/DisplayDevice"),
                         QStringLiteral("org.freedesktop.DBus.Properties"),
                         QDBusConnection::systemBus());
    if (!iface.isValid()) {
        setHasBattery(false);
        return;
    }
    auto getProp = [&](const QString &prop) -> QVariant {
        QDBusReply<QVariant> r = iface.call(QStringLiteral("Get"), QStringLiteral("org.freedesktop.UPower.Device"), prop);
        return r.isValid() ? r.value() : QVariant();
    };
    QVariant isPresent = getProp(QStringLiteral("IsPresent"));
    bool present = isPresent.isValid() ? isPresent.toBool() : true;
    // If DisplayDevice not present, try BAT0
    if (!present) {
        QDBusInterface iface2(QStringLiteral("org.freedesktop.UPower"),
                              QStringLiteral("/org/freedesktop/UPower/devices/battery_BAT0"),
                              QStringLiteral("org.freedesktop.DBus.Properties"),
                              QDBusConnection::systemBus());
        if (iface2.isValid()) {
            QDBusReply<QVariant> r2 = iface2.call(QStringLiteral("Get"), QStringLiteral("org.freedesktop.UPower.Device"), QStringLiteral("Percentage"));
            if (r2.isValid()) {
                present = true;
                double pct2 = r2.value().toDouble();
                QDBusReply<QVariant> rState = iface2.call(QStringLiteral("Get"), QStringLiteral("org.freedesktop.UPower.Device"), QStringLiteral("State"));
                uint state2 = rState.isValid() ? rState.value().toUInt() : 2;
                setHasBattery(true);
                setBatteryPercentage(int(std::round(pct2)));
                setCharging(state2 == 1 || state2 == 4);
                updateBatteryIcon();
                return;
            }
        }
    }
    if (!present) { setHasBattery(false); return; }
    double pct = getProp(QStringLiteral("Percentage")).toDouble();
    uint state = getProp(QStringLiteral("State")).toUInt(); // 1 charging, 2 discharging, 4 fully
    bool charging = (state == 1 || state == 4);
    setHasBattery(true);
    setBatteryPercentage(int(std::round(pct)));
    setCharging(charging);
    updateBatteryIcon();
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
    QString color = QStringLiteral("#4bd25c");
    if (!m_hasBattery) { icon = QStringLiteral("󰂃"); color = QStringLiteral("#4bd25c"); }
    else if (m_charging) { icon = QStringLiteral("󰂄"); color = QStringLiteral("#4bd25c"); }
    else {
        int p = m_batteryPercentage;
        if (p >= 90) icon = QStringLiteral("󰁹");
        else if (p >= 80) icon = QStringLiteral("󰂂");
        else if (p >= 60) icon = QStringLiteral("󰂀");
        else if (p >= 40) icon = QStringLiteral("󰁿");
        else if (p >= 20) icon = QStringLiteral("󰁽");
        else if (p >= 10) icon = QStringLiteral("󰁻");
        else icon = QStringLiteral("󰂃");
        if (p < 20) color = QStringLiteral("#e94545");
        else if (p < 40) color = QStringLiteral("#e9c46a");
    }
    if (m_batteryIcon != icon) { m_batteryIcon = icon; emit batteryIconChanged(); }
    if (m_batteryIconColor != color) { m_batteryIconColor = color; emit batteryIconColorChanged(); }
}
