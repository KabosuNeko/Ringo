#include "PowerProfileController.h"
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDBusMessage>
#include <QDBusArgument>
#include <QDebug>

static const QString SERVICE = QStringLiteral("net.hadess.PowerProfiles");
static const QString PATH = QStringLiteral("/net/hadess/PowerProfiles");
static const QString IFACE = QStringLiteral("net.hadess.PowerProfiles");
static const QString PROP_IFACE = QStringLiteral("org.freedesktop.DBus.Properties");

PowerProfileController::PowerProfileController(QObject *parent)
    : QObject(parent)
{
    initDBus();
    fetchProperties();
}

void PowerProfileController::initDBus()
{
    auto bus = QDBusConnection::systemBus();
    if (!bus.isConnected()) {
        qWarning() << "PowerProfileController: System D-Bus is not connected";
        return;
    }

    bus.connect(SERVICE, PATH, PROP_IFACE, QStringLiteral("PropertiesChanged"),
                 this, SLOT(onPropertiesChanged(QString, QVariantMap, QStringList)));
}

void PowerProfileController::fetchProperties()
{
    auto bus = QDBusConnection::systemBus();
    if (!bus.isConnected()) return;

    QDBusInterface iface(SERVICE, PATH, PROP_IFACE, bus);
    if (!iface.isValid()) {
        if (m_hasPowerProfiles) {
            m_hasPowerProfiles = false;
            emit hasPowerProfilesChanged();
        }
        return;
    }

    QDBusReply<QVariantMap> reply = iface.call(QStringLiteral("GetAll"), IFACE);
    if (!reply.isValid()) {
        if (m_hasPowerProfiles) {
            m_hasPowerProfiles = false;
            emit hasPowerProfilesChanged();
        }
        return;
    }

    if (!m_hasPowerProfiles) {
        m_hasPowerProfiles = true;
        emit hasPowerProfilesChanged();
    }

    const QVariantMap props = reply.value();
    if (props.contains(QStringLiteral("ActiveProfile"))) {
        setActiveProfile(props.value(QStringLiteral("ActiveProfile")).toString());
    }

    if (props.contains(QStringLiteral("Profiles"))) {
        QStringList profilesList;
        QVariant profilesVar = props.value(QStringLiteral("Profiles"));

        if (profilesVar.userType() == qMetaTypeId<QDBusArgument>()) {
            const QDBusArgument arg = profilesVar.value<QDBusArgument>();
            arg.beginArray();
            while (!arg.atEnd()) {
                QVariantMap profileMap;
                arg >> profileMap;
                if (profileMap.contains(QStringLiteral("Profile"))) {
                    profilesList << profileMap.value(QStringLiteral("Profile")).toString();
                }
            }
            arg.endArray();
        } else if (profilesVar.canConvert<QVariantList>()) {
            const QVariantList list = profilesVar.toList();
            for (const auto &item : list) {
                if (item.canConvert<QVariantMap>()) {
                    const QVariantMap m = item.toMap();
                    if (m.contains(QStringLiteral("Profile"))) {
                        profilesList << m.value(QStringLiteral("Profile")).toString();
                    }
                }
            }
        }

        if (profilesList.isEmpty()) {
            profilesList = {QStringLiteral("power-saver"), QStringLiteral("balanced"), QStringLiteral("performance")};
        }

        if (m_profiles != profilesList) {
            m_profiles = profilesList;
            emit profilesChanged();
        }
    } else if (m_profiles.isEmpty()) {
        m_profiles = {QStringLiteral("power-saver"), QStringLiteral("balanced"), QStringLiteral("performance")};
        emit profilesChanged();
    }
}

void PowerProfileController::setProfile(const QString &profile)
{
    if (profile.isEmpty() || profile == m_activeProfile) return;

    auto bus = QDBusConnection::systemBus();
    if (!bus.isConnected()) return;

    QDBusInterface iface(SERVICE, PATH, PROP_IFACE, bus);
    if (iface.isValid()) {
        iface.call(QStringLiteral("Set"), IFACE, QStringLiteral("ActiveProfile"),
                   QVariant::fromValue(QDBusVariant(profile)));
    }
}

void PowerProfileController::cycleNext()
{
    if (m_profiles.isEmpty()) {
        m_profiles = {QStringLiteral("power-saver"), QStringLiteral("balanced"), QStringLiteral("performance")};
    }

    int idx = m_profiles.indexOf(m_activeProfile);
    int nextIdx = (idx + 1) % m_profiles.size();
    setProfile(m_profiles.at(nextIdx));
}

void PowerProfileController::refresh()
{
    fetchProperties();
}

void PowerProfileController::onPropertiesChanged(const QString &interfaceName,
                                                 const QVariantMap &changedProperties,
                                                 const QStringList &invalidatedProperties)
{
    Q_UNUSED(invalidatedProperties);
    if (interfaceName != IFACE) return;

    if (changedProperties.contains(QStringLiteral("ActiveProfile"))) {
        setActiveProfile(changedProperties.value(QStringLiteral("ActiveProfile")).toString());
    }
    if (changedProperties.contains(QStringLiteral("Profiles"))) {
        fetchProperties();
    }
}

void PowerProfileController::setActiveProfile(const QString &profile)
{
    if (m_activeProfile != profile) {
        m_activeProfile = profile;
        emit activeProfileChanged();
    }
}
