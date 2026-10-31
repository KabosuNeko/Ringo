// Small model test: duplicate object paths must update one row, removals must
// not shift another device's data, and connectedDeviceName must follow updates.
#include "BluetoothDeviceModel.h"

#include <QCoreApplication>
#include <cassert>

int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    BluetoothDeviceModel model;

    BluetoothDeviceModel::Device keyboard;
    keyboard.objectPath = QStringLiteral("/org/bluez/hci0/dev_AA");
    keyboard.address = QStringLiteral("AA");
    keyboard.name = QStringLiteral("Keyboard");
    keyboard.paired = true;
    keyboard.rssi = -40;
    keyboard.battery = 80;
    assert(model.upsertDevice(keyboard));
    assert(model.rowCount() == 1);

    keyboard.connected = true;
    assert(!model.upsertDevice(keyboard));
    assert(model.rowCount() == 1);
    assert(model.connectedDeviceName() == QStringLiteral("Keyboard"));

    BluetoothDeviceModel::Device mouse;
    mouse.objectPath = QStringLiteral("/org/bluez/hci0/dev_BB");
    mouse.address = QStringLiteral("BB");
    mouse.name = QStringLiteral("Mouse");
    assert(model.upsertDevice(mouse));
    assert(model.rowCount() == 2);

    model.updateBattery(mouse.objectPath, 55);
    assert(model.data(model.index(1), BluetoothDeviceModel::BatteryRole).toInt() == 55);

    assert(model.removeDeviceByPath(keyboard.objectPath));
    assert(model.rowCount() == 1);
    assert(model.data(model.index(0), BluetoothDeviceModel::AddressRole).toString()
           == QStringLiteral("BB"));
    return 0;
}
