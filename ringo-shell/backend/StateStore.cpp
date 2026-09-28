#include "StateStore.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QStandardPaths>
#include <QTimer>

namespace {
constexpr int kSaveDelayMs = 400;
} // namespace

StateStore &StateStore::instance() {
    static StateStore store;
    return store;
}

StateStore::StateStore(QObject *parent) : QObject(parent) {
    // QStandardPaths::StateLocation only exists from Qt 6.9.
#if QT_VERSION >= QT_VERSION_CHECK(6, 9, 0)
    const QString stateRoot = QStandardPaths::writableLocation(QStandardPaths::StateLocation);
#else
    const QString stateRoot = qEnvironmentVariable(
        "XDG_STATE_HOME", QDir::homePath() + QStringLiteral("/.local/state"));
#endif
    const QString dir = stateRoot + QStringLiteral("/ringo-shell");
    m_path = dir + QStringLiteral("/state.json");

    m_saveTimer = new QTimer(this);
    m_saveTimer->setSingleShot(true);
    m_saveTimer->setInterval(kSaveDelayMs);
    connect(m_saveTimer, &QTimer::timeout, this, &StateStore::save);

    load();
}

void StateStore::load() {
    QFile file(m_path);
    if (!file.open(QIODevice::ReadOnly)) return;

    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    if (doc.isObject()) m_values = doc.object().toVariantMap();
}

QVariant StateStore::get(const QString &key, const QVariant &fallback) const {
    const auto it = m_values.constFind(key);
    return it == m_values.constEnd() ? fallback : it.value();
}

void StateStore::set(const QString &key, const QVariant &value) {
    if (m_values.value(key) == value) return;
    m_values.insert(key, value);
    scheduleSave();
}

void StateStore::remove(const QString &key) {
    if (m_values.remove(key) == 0) return;
    scheduleSave();
}

void StateStore::scheduleSave() {
    m_saveTimer->start();
}

void StateStore::save() {
    const QFileInfo info(m_path);
    if (!QDir().mkpath(info.absolutePath())) return;

    QSaveFile file(m_path);
    if (!file.open(QIODevice::WriteOnly)) return;
    file.write(QJsonDocument(QJsonObject::fromVariantMap(m_values)).toJson(QJsonDocument::Indented));
    file.commit();
}
