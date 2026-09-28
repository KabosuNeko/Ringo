#pragma once
#include <QObject>
#include <QString>
#include <QVariant>
#include <QVariantMap>

class QTimer;

// Tiny persistent key/value store for runtime state that survives a shell restart
// (wallpaper mode, night light toggle); lives in the XDG state dir, debounced.
class StateStore final : public QObject {
    Q_OBJECT

public:
    static StateStore &instance();

    QVariant get(const QString &key, const QVariant &fallback = {}) const;
    void set(const QString &key, const QVariant &value);
    void remove(const QString &key);

private:
    explicit StateStore(QObject *parent = nullptr);

    void load();
    void scheduleSave();
    void save();

    QString m_path;
    QVariantMap m_values;
    QTimer *m_saveTimer = nullptr;
};
