#pragma once
#include <QObject>
#include <QTimer>
#include <QElapsedTimer>
#include <QNetworkInterface>
#include <QSysInfo>
#include <QtQml/qqml.h>

class SystemMonitor final : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QString rxRate READ rxRate NOTIFY rxRateChanged)
    Q_PROPERTY(QString txRate READ txRate NOTIFY txRateChanged)
    Q_PROPERTY(QString ip READ ip NOTIFY ipChanged)
    Q_PROPERTY(QString iface READ iface NOTIFY ifaceChanged)
    Q_PROPERTY(bool vpn READ vpn NOTIFY vpnChanged)
    Q_PROPERTY(bool hasBattery READ hasBattery NOTIFY hasBatteryChanged)
    Q_PROPERTY(int batteryPercentage READ batteryPercentage NOTIFY batteryPercentageChanged)
    Q_PROPERTY(bool charging READ charging NOTIFY chargingChanged)
    Q_PROPERTY(QString batteryIcon READ batteryIcon NOTIFY batteryIconChanged)
    Q_PROPERTY(QString batteryIconColor READ batteryIconColor NOTIFY batteryIconColorChanged)
    Q_PROPERTY(QString uptime READ uptime NOTIFY uptimeChanged)
    Q_PROPERTY(bool hasBatteryInternal READ hasBatteryInternal NOTIFY hasBatteryChanged)
    Q_PROPERTY(QString username READ username CONSTANT)
    Q_PROPERTY(QString hostname READ hostname CONSTANT)
    Q_PROPERTY(int cpuPercent READ cpuPercent NOTIFY cpuPercentChanged)
    Q_PROPERTY(int cpuUsage READ cpuPercent NOTIFY cpuPercentChanged)
    Q_PROPERTY(int ramPercent READ ramPercent NOTIFY ramPercentChanged)
    Q_PROPERTY(int ramUsage READ ramPercent NOTIFY ramPercentChanged)
    Q_PROPERTY(QString ramDetail READ ramDetail NOTIFY ramDetailChanged)
    Q_PROPERTY(bool telemetryActive READ telemetryActive WRITE setTelemetryActive NOTIFY telemetryActiveChanged)

public:
    explicit SystemMonitor(QObject *parent = nullptr);

    QString username() const {
        const QString u = qEnvironmentVariable("USER");
        return u.isEmpty() ? qEnvironmentVariable("LOGNAME") : u;
    }
    QString hostname() const { return QSysInfo::machineHostName(); }

    QString rxRate() const { return m_rxRate; }
    QString txRate() const { return m_txRate; }
    QString ip() const { return m_ip; }
    QString iface() const { return m_iface; }
    bool vpn() const { return m_vpn; }
    bool hasBattery() const { return m_hasBattery; }
    bool hasBatteryInternal() const { return m_hasBattery; }
    int batteryPercentage() const { return m_batteryPercentage; }
    bool charging() const { return m_charging; }
    QString batteryIcon() const { return m_batteryIcon; }
    QString batteryIconColor() const { return m_batteryIconColor; }
    QString uptime() const { return m_uptime; }
    int cpuPercent() const { return m_cpuPercent; }
    int ramPercent() const { return m_ramPercent; }
    QString ramDetail() const { return m_ramDetail; }
    bool telemetryActive() const { return m_telemetryActive; }
    void setTelemetryActive(bool active);

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void refreshBandwidth();
    Q_INVOKABLE void refreshTelemetry();
    Q_INVOKABLE void refreshNetwork();
    Q_INVOKABLE void refreshBattery();
    Q_INVOKABLE void refreshUptime();

signals:
    void rxRateChanged();
    void txRateChanged();
    void ipChanged();
    void ifaceChanged();
    void vpnChanged();
    void hasBatteryChanged();
    void batteryPercentageChanged();
    void chargingChanged();
    void batteryIconChanged();
    void batteryIconColorChanged();
    void uptimeChanged();
    void cpuPercentChanged();
    void ramPercentChanged();
    void ramDetailChanged();
    void telemetryActiveChanged();

private slots:
    void pollTelemetry();
    void pollBandwidth();
    void pollNetwork();
    void pollUptime();
    void pollBattery();
    void handleUPowerPropertiesChanged(const QString &interface, const QVariantMap &changed, const QStringList &invalidated);

private:
    static QString fmtRate(double bps);
    static QString fmtUptime(double seconds);
    void updateBatteryIcon();
    void pollCpu();
    void pollRam();
    void setRxRate(const QString &v);
    void setTxRate(const QString &v);
    void setIp(const QString &v);
    void setIface(const QString &v);
    void setVpn(bool v);
    void setHasBattery(bool v);
    void setBatteryPercentage(int v);
    void setCharging(bool v);
    void setUptime(const QString &v);

    QString m_rxRate = QStringLiteral("... ");
    QString m_txRate = QStringLiteral("... ");
    QString m_ip = QStringLiteral("...");
    QString m_iface = QStringLiteral("...");
    bool m_vpn = false;
    bool m_hasBattery = false;
    int m_batteryPercentage = 0;
    bool m_charging = false;
    QString m_batteryIcon = QStringLiteral("󰂃");
    QString m_batteryIconColor = QStringLiteral("#4bd25c");
    QString m_uptime = QStringLiteral("...");

    int m_cpuPercent = 0;
    int m_ramPercent = 0;
    QString m_ramDetail = QStringLiteral("-- / -- GB");
    bool m_telemetryActive = false;

    quint64 m_prevCpuTotal = 0;
    quint64 m_prevCpuIdle = 0;

    double m_prevRx = -1;
    double m_prevTx = -1;

    QTimer m_telemetryTimer;
    QTimer m_netTimer;
    QTimer m_uptimeTimer;
    QTimer m_batTimer;
};
