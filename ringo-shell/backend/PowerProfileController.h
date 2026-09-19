#pragma once
#include <QObject>
#include <QStringList>
#include <QVariantMap>
#include <QtQml/qqml.h>

class PowerProfileController final : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QString activeProfile READ activeProfile WRITE setProfile NOTIFY activeProfileChanged)
    Q_PROPERTY(QStringList profiles READ profiles NOTIFY profilesChanged)
    Q_PROPERTY(bool hasPowerProfiles READ hasPowerProfiles NOTIFY hasPowerProfilesChanged)

public:
    explicit PowerProfileController(QObject *parent = nullptr);

    QString activeProfile() const { return m_activeProfile; }
    QStringList profiles() const { return m_profiles; }
    bool hasPowerProfiles() const { return m_hasPowerProfiles; }

    Q_INVOKABLE void setProfile(const QString &profile);
    Q_INVOKABLE void cycleNext();
    Q_INVOKABLE void refresh();

signals:
    void activeProfileChanged();
    void profilesChanged();
    void hasPowerProfilesChanged();

private slots:
    void onPropertiesChanged(const QString &interfaceName,
                             const QVariantMap &changedProperties,
                             const QStringList &invalidatedProperties);

private:
    void initDBus();
    void fetchProperties();
    void setActiveProfile(const QString &profile);

    QString m_activeProfile = QStringLiteral("balanced");
    QStringList m_profiles;
    bool m_hasPowerProfiles = false;
};
