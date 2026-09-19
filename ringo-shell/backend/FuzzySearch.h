#pragma once
#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqml.h>

class FuzzySearch final : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit FuzzySearch(QObject *parent = nullptr);

    Q_INVOKABLE int score(const QString &pattern, const QString &target) const;
    Q_INVOKABLE QVariantList filterAndSort(const QVariantList &apps,
                                          const QString &query,
                                          const QString &category) const;

private:
    static bool matchesCategory(const QVariantMap &appMap, const QString &category);
};
