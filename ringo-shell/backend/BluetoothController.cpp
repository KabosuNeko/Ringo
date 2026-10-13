#include "BluetoothController.h"
#include "BluetoothDeviceModel.h"
#include "StateStore.h"

#include <QDBusConnection>
#include <QDBusMetaType>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusPendingCall>
#include <QDBusReply>
#include <QDBusVariant>
#include <QVariantMap>

namespace {
constexpr const char *kBluezService = "org.bluez";
constexpr const char *kDeviceIface = "org.bluez.Device1";
constexpr const char *kAdapterIface = "org.bluez.Adapter1";
constexpr const char *kBatteryIface = "org.bluez.Battery1";
const QString kEnabledKey = QStringLiteral("bluetooth.enabled");
}

BluetoothController::BluetoothController(QObject *parent)
    : QObject(parent), m_devices(new BluetoothDeviceModel(this)) {
    // Without this the composite reply type has no D-Bus signature until some
    // other controller registers it, and getManagedObjects() decodes as invalid.
    qDBusRegisterMetaType<QMap<QDBusObjectPath, QMap<QString, QVariantMap>>>();

    // Only the UI toggle persists; it is the user's intent, applied once the adapter shows up.
    m_storedEnabled = StateStore::instance().get(kEnabledKey);

    // bluez appearing/disappearing on the bus
    QDBusConnection::systemBus().connect(
        QString(), "/org/freedesktop/DBus", "org.freedesktop.DBus",
        "NameOwnerChanged", this, SLOT(handleBluezNameOwnerChanged(QString, QString, QString)));

    connect(this, &BluetoothController::scanningChanged, this, &BluetoothController::statusTextChanged);
    connect(this, &BluetoothController::busyChanged, this, &BluetoothController::statusTextChanged);

    // cold boot: bluetoothd claims the bus name before hci0 finishes firmware init,
    // so a failed adapter lookup at startup must not be permanent
    m_adapterRetryTimer = new QTimer(this);
    m_adapterRetryTimer->setInterval(1500);
    connect(m_adapterRetryTimer, &QTimer::timeout, this, &BluetoothController::retryFindAdapter);

    connectToBluez();
}

BluetoothController::~BluetoothController() {
    disconnectFromBluez();
}

bool BluetoothController::enabled() const { return m_adapterPowered; }
bool BluetoothController::scanning() const { return m_scanning; }
bool BluetoothController::busy() const { return m_busy; }
QString BluetoothController::errorMessage() const { return m_errorMessage; }
QString BluetoothController::currentDeviceName() const { return m_currentDeviceName; }
QString BluetoothController::statusText() const {
    if (m_scanning) return "Scanning...";
    if (m_busy) return "Working...";
    return {};
}
BluetoothDeviceModel *BluetoothController::devices() const { return m_devices; }
QString BluetoothController::adapterName() const { return m_adapterName; }

void BluetoothController::setAdapterName(const QString &name) {
    if (m_adapterName == name) return;
    m_adapterName = name;
    emit adapterNameChanged();
}

void BluetoothController::setEnabledState(bool on) {
    if (m_adapterPowered == on) return;
    m_adapterPowered = on;
    emit enabledChanged();
    if (!on) {
        setScanning(false);
        m_devices->clear();
        refreshCurrentDeviceName();
    }
}

void BluetoothController::setScanning(bool on) {
    if (m_scanning == on) return;
    m_scanning = on;
    emit scanningChanged();
}

void BluetoothController::setBusy(bool on) {
    if (m_busy == on) return;
    m_busy = on;
    emit busyChanged();
}

void BluetoothController::setErrorMessage(const QString &error) {
    if (m_errorMessage == error) return;
    m_errorMessage = error;
    emit errorMessageChanged();
}

void BluetoothController::connectToBluez() {
    auto bus = QDBusConnection::systemBus();

    // live device add/remove
    bus.connect(kBluezService, "/", "org.freedesktop.DBus.ObjectManager",
                "InterfacesAdded", this, SLOT(handleInterfacesAdded(QDBusMessage)));
    bus.connect(kBluezService, "/", "org.freedesktop.DBus.ObjectManager",
                "InterfacesRemoved", this, SLOT(handleInterfacesRemoved(QDBusMessage)));

    bus.connect(kBluezService, QString(), "org.freedesktop.DBus.Properties",
                "PropertiesChanged", this, SLOT(handlePropertiesChanged(QDBusMessage)));

    if (findAdapter()) {
        m_adapterRetryTimer->stop();
        m_adapterRetriesLeft = 0;
        populateExistingDevices();
    } else {
        setErrorMessage("No Bluetooth adapter found");
        startAdapterRetry();
    }
}

void BluetoothController::restoreStoredEnabled() {
    if (m_restoreDone) return; // apply once: from here on the user toggling by hand wins
    m_restoreDone = true;

    // First run (or the toggle never used): nothing stored, so adopt what the adapter says.
    if (!m_storedEnabled.isValid() || m_storedEnabled.toBool() == m_adapterPowered) return;

    setEnabled(m_storedEnabled.toBool());
}

void BluetoothController::startAdapterRetry() {
    if (!m_adapterPath.isEmpty()) return; // already have one, nothing to retry
    m_adapterRetriesLeft = 8; // ~12s of polling, generous for slow firmware init on cold boot
    m_adapterRetryTimer->start();
}

void BluetoothController::retryFindAdapter() {
    if (!m_adapterPath.isEmpty()) {
        m_adapterRetryTimer->stop();
        return;
    }
    if (--m_adapterRetriesLeft <= 0) {
        m_adapterRetryTimer->stop();
        return; // give up quietly - NameOwnerChanged/InterfacesAdded will still catch it later
    }
    if (findAdapter()) {
        m_adapterRetryTimer->stop();
        populateExistingDevices();
    }
}

void BluetoothController::disconnectFromBluez() {
    auto bus = QDBusConnection::systemBus();
    bus.disconnect(kBluezService, "/", "org.freedesktop.DBus.ObjectManager",
                    "InterfacesAdded", this, SLOT(handleInterfacesAdded(QDBusMessage)));
    bus.disconnect(kBluezService, "/", "org.freedesktop.DBus.ObjectManager",
                    "InterfacesRemoved", this, SLOT(handleInterfacesRemoved(QDBusMessage)));
    bus.disconnect(kBluezService, QString(), "org.freedesktop.DBus.Properties",
                    "PropertiesChanged", this, SLOT(handlePropertiesChanged(QDBusMessage)));
}

void BluetoothController::handleBluezNameOwnerChanged(const QString &name, const QString &oldOwner,
                                                        const QString &newOwner) {
    if (name != kBluezService) return;

    if (!newOwner.isEmpty() && oldOwner.isEmpty()) {
        // bluez (re)started
        setErrorMessage(QString());
        connectToBluez();
    } else if (newOwner.isEmpty()) {
        // bluez went away
        m_adapterRetryTimer->stop();
        m_adapterPath.clear();
        setEnabledState(false);
        setErrorMessage("bluetoothd is not running");
    }
}

bool BluetoothController::findAdapter() {
    QDBusInterface manager(kBluezService, "/", "org.freedesktop.DBus.ObjectManager",
                            QDBusConnection::systemBus());
    QDBusReply<QMap<QDBusObjectPath, QMap<QString, QVariantMap>>> reply =
        manager.call("GetManagedObjects");

    if (!reply.isValid()) {
        // whatever the D-Bus reason (bluetoothd off, activation race), it means the
        // same thing to the user, so show our own message, not bluez's raw text
        setErrorMessage("No Bluetooth adapter found");
        return false;
    }

    for (auto it = reply.value().constBegin(); it != reply.value().constEnd(); ++it) {
        const auto &interfaces = it.value();
        if (!interfaces.contains(kAdapterIface)) continue;

        m_adapterPath = it.key().path();
        const QVariantMap adapterProps = interfaces.value(kAdapterIface);
        setEnabledState(adapterProps.value("Powered", false).toBool());
        setAdapterName(adapterProps.value("Alias", adapterProps.value("Name")).toString());
        restoreStoredEnabled();
        setErrorMessage(QString()); // clear any stale "no adapter" error from an earlier failed lookup
        return true;
    }

    return false;
}

void BluetoothController::populateExistingDevices() {
    QDBusInterface manager(kBluezService, "/", "org.freedesktop.DBus.ObjectManager",
                            QDBusConnection::systemBus());
    QDBusReply<QMap<QDBusObjectPath, QMap<QString, QVariantMap>>> reply =
        manager.call("GetManagedObjects");
    if (!reply.isValid()) return;

    for (auto it = reply.value().constBegin(); it != reply.value().constEnd(); ++it) {
        const QString path = it.key().path();
        if (!path.startsWith(m_adapterPath)) continue; // device must belong to our adapter

        const auto &interfaces = it.value();
        if (!interfaces.contains(kDeviceIface)) continue;

        applyDeviceProperties(path, interfaces.value(kDeviceIface), /*insertIfMissing=*/true);
    }
}

void BluetoothController::refreshCurrentDeviceName() {
    const QString name = m_devices->connectedDeviceName();
    if (name == m_currentDeviceName) return;
    m_currentDeviceName = name;
    emit currentDeviceNameChanged();
}

void BluetoothController::applyDeviceProperties(const QString &objectPath, const QVariantMap &props,
                                                  bool insertIfMissing) {
    const int existingIdx = m_devices->indexOfPath(objectPath);
    if (existingIdx < 0 && !insertIfMissing) return;

    BluetoothDeviceModel::Device d;
    d.objectPath = objectPath;

    // When updating an existing device, start from the cached state and
    // overlay only the fields that PropertiesChanged actually delivered.
    // This avoids a synchronous D-Bus GetAll round-trip on every RSSI tick.
    if (existingIdx >= 0) {
        d = m_devices->deviceAt(existingIdx);
    } else {
        d.battery = -1;
    }

    if (props.contains(QStringLiteral("Address")))
        d.address = props.value(QStringLiteral("Address")).toString();
    if (props.contains(QStringLiteral("Alias")))
        d.name = props.value(QStringLiteral("Alias")).toString();
    else if (props.contains(QStringLiteral("Name")))
        d.name = props.value(QStringLiteral("Name")).toString();
    if (props.contains(QStringLiteral("Paired")))
        d.paired = props.value(QStringLiteral("Paired")).toBool();
    if (props.contains(QStringLiteral("Connected")))
        d.connected = props.value(QStringLiteral("Connected")).toBool();
    if (props.contains(QStringLiteral("RSSI")))
        d.rssi = props.value(QStringLiteral("RSSI")).toInt();

    m_devices->upsertDevice(d);
    refreshCurrentDeviceName();
}

void BluetoothController::handleInterfacesAdded(const QDBusMessage &msg) {
    const QList<QVariant> args = msg.arguments();
    if (args.size() < 2) return;

    const QString path = args.at(0).value<QDBusObjectPath>().path();
    const auto interfaces = qdbus_cast<QMap<QString, QVariantMap>>(args.at(1));

    // adapter showing up late
    if (m_adapterPath.isEmpty() && interfaces.contains(kAdapterIface)) {
        m_adapterPath = path;
        m_adapterRetryTimer->stop();
        setErrorMessage(QString());
        const QVariantMap adapterProps = interfaces.value(kAdapterIface);
        setEnabledState(adapterProps.value("Powered", false).toBool());
        setAdapterName(adapterProps.value("Alias", adapterProps.value("Name")).toString());
        restoreStoredEnabled();
        populateExistingDevices();
        return;
    }

    if (!path.startsWith(m_adapterPath)) return;

    if (interfaces.contains(kBatteryIface)) {
        const QVariantMap batProps = interfaces.value(kBatteryIface);
        if (batProps.contains("Percentage"))
            m_devices->updateBattery(path, batProps.value("Percentage").toInt());
    }

    if (!interfaces.contains(kDeviceIface)) return;
    applyDeviceProperties(path, interfaces.value(kDeviceIface), /*insertIfMissing=*/true);
}

void BluetoothController::handleInterfacesRemoved(const QDBusMessage &msg) {
    const QList<QVariant> args = msg.arguments();
    if (args.size() < 2) return;

    const QString path = args.at(0).value<QDBusObjectPath>().path();
    const QStringList removedInterfaces = args.at(1).toStringList();
    if (removedInterfaces.contains(kDeviceIface)) {
        m_devices->removeDeviceByPath(path);
        refreshCurrentDeviceName();
    }
}

void BluetoothController::handlePropertiesChanged(const QDBusMessage &msg) {
    // path comes from the message, not the PropertiesChanged args
    const QString path = msg.path();
    const QList<QVariant> args = msg.arguments();
    if (args.isEmpty()) return;

    const QString iface = args.at(0).toString();

    if (iface == kAdapterIface && path == m_adapterPath) {
        const QVariantMap changed = args.size() > 1 ? qdbus_cast<QVariantMap>(args.at(1)) : QVariantMap();
        if (changed.contains("Powered")) setEnabledState(changed.value("Powered").toBool());
        if (changed.contains("Discovering")) setScanning(changed.value("Discovering").toBool());
        if (changed.contains("Alias")) setAdapterName(changed.value("Alias").toString());
        return;
    }

    if (iface == kDeviceIface && path.startsWith(m_adapterPath)) {
        const QVariantMap changed = args.size() > 1 ? qdbus_cast<QVariantMap>(args.at(1)) : QVariantMap();
        applyDeviceProperties(path, changed, /*insertIfMissing=*/false);
    }

    if (iface == kBatteryIface && path.startsWith(m_adapterPath)) {
        const QVariantMap changed = args.size() > 1 ? qdbus_cast<QVariantMap>(args.at(1)) : QVariantMap();
        if (changed.contains("Percentage"))
            m_devices->updateBattery(path, changed.value("Percentage").toInt());
        return;
    }
}

QString BluetoothController::devicePathForAddress(const QString &address) const {
    if (m_adapterPath.isEmpty()) return {};
    QString normalized = address;
    normalized.replace(':', '_');
    return m_adapterPath + "/dev_" + normalized;
}

void BluetoothController::asyncCallNoReply(const QString &objectPath, const QString &interface,
                                             const QString &method, const QVariantList &args) {
    QDBusMessage call = QDBusMessage::createMethodCall(kBluezService, objectPath, interface, method);
    call.setArguments(args);
    QDBusConnection::systemBus().asyncCall(call);
}

void BluetoothController::setEnabled(bool on) {
    if (m_adapterPath.isEmpty()) {
        setErrorMessage("No Bluetooth adapter found");
        return;
    }
    QDBusInterface adapterProps(kBluezService, m_adapterPath, "org.freedesktop.DBus.Properties",
                                 QDBusConnection::systemBus());
    QDBusReply<void> reply = adapterProps.call("Set", kAdapterIface, "Powered", QVariant::fromValue(QDBusVariant(on)));
    if (!reply.isValid()) {
        setErrorMessage(reply.error().message());
        return;
    }
    StateStore::instance().set(kEnabledKey, on); // remember the intent for the next start
    // PropertiesChanged signal will flip m_adapterPowered once bluez confirms it
}

void BluetoothController::refreshDevices(bool discover) {
    if (m_adapterPath.isEmpty() || !m_adapterPowered) return;

    populateExistingDevices();

    if (!discover) return;

    setBusy(true);
    QDBusMessage call = QDBusMessage::createMethodCall(kBluezService, m_adapterPath,
                                                         kAdapterIface, "StartDiscovery");
    auto pending = QDBusConnection::systemBus().asyncCall(call);
    auto *watcher = new QDBusPendingCallWatcher(pending, this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher]() {
        watcher->deleteLater();
        setBusy(false);
        QDBusPendingReply<> reply = *watcher;
        if (reply.isError()) {
            // "already in progress" is not a real failure
            if (reply.error().name() != "org.bluez.Error.InProgress")
                setErrorMessage(reply.error().message());
        } else {
            setScanning(true);
        }
    });
}

void BluetoothController::pairDevice(const QString &address) {
    const QString path = devicePathForAddress(address);
    if (path.isEmpty()) return;

    setBusy(true);
    setErrorMessage(QString());
    QDBusMessage call = QDBusMessage::createMethodCall(kBluezService, path, kDeviceIface, "Pair");
    auto pending = QDBusConnection::systemBus().asyncCall(call);
    auto *watcher = new QDBusPendingCallWatcher(pending, this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher, address]() {
        watcher->deleteLater();
        setBusy(false);
        QDBusPendingReply<> reply = *watcher;
        if (reply.isError()) {
            setErrorMessage("Pairing with " + address + " failed: " + reply.error().message());
        } else {
            // trust it once paired so future connects need no re-authorization
            asyncCallNoReply(devicePathForAddress(address), "org.freedesktop.DBus.Properties", "Set",
                { QVariant("org.bluez.Device1"), QVariant("Trusted"), QVariant::fromValue(QDBusVariant(true)) });
        }
    });
}

void BluetoothController::connectDevice(const QString &address) {
    const QString path = devicePathForAddress(address);
    if (path.isEmpty()) return;

    setBusy(true);
    setErrorMessage(QString());
    QDBusMessage call = QDBusMessage::createMethodCall(kBluezService, path, kDeviceIface, "Connect");
    auto pending = QDBusConnection::systemBus().asyncCall(call);
    auto *watcher = new QDBusPendingCallWatcher(pending, this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher, address]() {
        watcher->deleteLater();
        setBusy(false);
        QDBusPendingReply<> reply = *watcher;
        if (reply.isError())
            setErrorMessage("Connecting to " + address + " failed: " + reply.error().message());
    });
}

void BluetoothController::disconnectDevice(const QString &address) {
    const QString path = devicePathForAddress(address);
    if (path.isEmpty()) return;

    setBusy(true);
    QDBusMessage call = QDBusMessage::createMethodCall(kBluezService, path, kDeviceIface, "Disconnect");
    auto pending = QDBusConnection::systemBus().asyncCall(call);
    auto *watcher = new QDBusPendingCallWatcher(pending, this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher, address]() {
        watcher->deleteLater();
        setBusy(false);
        QDBusPendingReply<> reply = *watcher;
        if (reply.isError())
            setErrorMessage("Disconnecting " + address + " failed: " + reply.error().message());
    });
}

void BluetoothController::forgetDevice(const QString &address) {
    if (m_adapterPath.isEmpty()) return;
    const QString path = devicePathForAddress(address);
    if (path.isEmpty()) return;

    setBusy(true);
    setErrorMessage(QString());
    // RemoveDevice lives on the adapter, not the device: it unpairs and drops the object
    QDBusMessage call = QDBusMessage::createMethodCall(kBluezService, m_adapterPath, kAdapterIface, "RemoveDevice");
    call.setArguments({ QVariant::fromValue(QDBusObjectPath(path)) });
    auto pending = QDBusConnection::systemBus().asyncCall(call);
    auto *watcher = new QDBusPendingCallWatcher(pending, this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher, address, path]() {
        watcher->deleteLater();
        setBusy(false);
        QDBusPendingReply<> reply = *watcher;
        if (reply.isError()) {
            setErrorMessage("Forgetting " + address + " failed: " + reply.error().message());
        } else {
            // InterfacesRemoved also fires this, but do it eagerly so the UI does
            // not wait on the signal round-trip
            m_devices->removeDeviceByPath(path);
            refreshCurrentDeviceName();
        }
    });
}
