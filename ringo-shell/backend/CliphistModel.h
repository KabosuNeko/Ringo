#pragma once
#include <QAbstractListModel>
#include <QString>
#include <QVector>
#include <QVariantMap>
#include <QProcess>
#include <QtQml/qqml.h>

struct ClipEntry {
    QString id;
    QString label;
    QString rawLine;
    bool isImage = false;
    QString imagePath;
};

class CliphistModel final : public QAbstractListModel {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(int totalCount READ totalCount NOTIFY totalCountChanged)
    Q_PROPERTY(QString searchQuery READ searchQuery WRITE setSearchQuery NOTIFY searchQueryChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)

public:
    enum Roles {
        ClipIdRole = Qt::UserRole + 1,
        LabelRole,
        IsImageRole,
        ImagePathRole,
        RawLineRole
    };

    explicit CliphistModel(QObject *parent = nullptr);
    ~CliphistModel() override;

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const { return m_filteredEntries.size(); }
    int totalCount() const { return m_allEntries.size(); }
    QString searchQuery() const { return m_searchQuery; }
    bool loading() const { return m_loading; }

    void setSearchQuery(const QString &query);

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void copyItem(int index);
    Q_INVOKABLE void copyById(const QString &id);
    Q_INVOKABLE void deleteItem(int index);
    Q_INVOKABLE void deleteById(const QString &id);
    Q_INVOKABLE void clearAll();
    Q_INVOKABLE QVariantMap get(int index) const;

signals:
    void countChanged();
    void totalCountChanged();
    void searchQueryChanged();
    void loadingChanged();

private slots:
    void onListProcessFinished(int exitCode, QProcess::ExitStatus exitStatus);

private:
    void applyFilter();
    void decodeThumbnail(const ClipEntry &entry);
    void pruneCache();

    QVector<ClipEntry> m_allEntries;
    QVector<ClipEntry> m_filteredEntries;
    QString m_searchQuery;
    bool m_loading = false;
    QString m_cacheDir;
    QProcess *m_listProcess = nullptr;
};
