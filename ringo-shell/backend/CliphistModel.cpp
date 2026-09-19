#include "CliphistModel.h"
#include <QDir>
#include <QFileInfo>
#include <QDateTime>
#include <QThreadPool>
#include <QDebug>

CliphistModel::CliphistModel(QObject *parent)
    : QAbstractListModel(parent)
{
    m_cacheDir = QDir::homePath() + QStringLiteral("/.cache/ringo-shell/cliphist-imgs");
    QDir().mkpath(m_cacheDir);

    pruneCache();
    refresh();
}

CliphistModel::~CliphistModel()
{
    if (m_listProcess && m_listProcess->state() != QProcess::NotRunning) {
        m_listProcess->kill();
        m_listProcess->waitForFinished(500);
    }
}

int CliphistModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) return 0;
    return m_filteredEntries.size();
}

QVariant CliphistModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_filteredEntries.size()) {
        return QVariant();
    }

    const ClipEntry &entry = m_filteredEntries.at(index.row());
    switch (role) {
    case ClipIdRole:
        return entry.id;
    case LabelRole:
        return entry.label;
    case IsImageRole:
        return entry.isImage;
    case ImagePathRole:
        return entry.imagePath;
    case RawLineRole:
        return entry.rawLine;
    default:
        return QVariant();
    }
}

QHash<int, QByteArray> CliphistModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[ClipIdRole] = "clipId";
    roles[LabelRole] = "label";
    roles[IsImageRole] = "isImage";
    roles[ImagePathRole] = "imagePath";
    roles[RawLineRole] = "rawLine";
    return roles;
}

void CliphistModel::setSearchQuery(const QString &query)
{
    if (m_searchQuery == query) return;
    m_searchQuery = query;
    emit searchQueryChanged();
    applyFilter();
}

void CliphistModel::refresh()
{
    if (m_listProcess) {
        if (m_listProcess->state() != QProcess::NotRunning) {
            m_listProcess->kill();
        }
        m_listProcess->deleteLater();
        m_listProcess = nullptr;
    }

    m_loading = true;
    emit loadingChanged();

    m_listProcess = new QProcess(this);
    connect(m_listProcess, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &CliphistModel::onListProcessFinished);

    m_listProcess->start(QStringLiteral("cliphist"), {QStringLiteral("list")});
}

void CliphistModel::onListProcessFinished(int exitCode, QProcess::ExitStatus exitStatus)
{
    Q_UNUSED(exitCode);
    Q_UNUSED(exitStatus);

    if (!m_listProcess) return;

    const QByteArray output = m_listProcess->readAllStandardOutput();
    m_listProcess->deleteLater();
    m_listProcess = nullptr;

    QVector<ClipEntry> newEntries;
    const QList<QByteArray> lines = output.split('\n');
    newEntries.reserve(lines.size());

    for (const QByteArray &line : lines) {
        if (line.isEmpty()) continue;

        int tabIdx = line.indexOf('\t');
        if (tabIdx == -1) continue;

        QString id = QString::fromUtf8(line.left(tabIdx));
        QString label = QString::fromUtf8(line.mid(tabIdx + 1));
        QString rawLine = QString::fromUtf8(line);

        ClipEntry entry;
        entry.id = id;
        entry.label = label;
        entry.rawLine = rawLine;

        if (label.contains(QStringLiteral("[[ binary data"))) {
            entry.isImage = true;
            entry.imagePath = m_cacheDir + QLatin1Char('/') + id + QStringLiteral(".png");
            if (!QFileInfo::exists(entry.imagePath)) {
                decodeThumbnail(entry);
            }
        }

        newEntries.append(entry);
    }

    m_allEntries = std::move(newEntries);
    m_loading = false;

    emit loadingChanged();
    emit totalCountChanged();

    applyFilter();
}

void CliphistModel::decodeThumbnail(const ClipEntry &entry)
{
    const QString rawLine = entry.rawLine;
    const QString targetPath = entry.imagePath;
    const QString id = entry.id;

    QThreadPool::globalInstance()->start([rawLine, targetPath, id, this]() {
        QProcess proc;
        proc.start(QStringLiteral("cliphist"), {QStringLiteral("decode")});
        if (proc.waitForStarted(1000)) {
            proc.write((rawLine + QLatin1Char('\n')).toUtf8());
            proc.closeWriteChannel();
            if (proc.waitForFinished(2000)) {
                QByteArray imgData = proc.readAllStandardOutput();
                if (!imgData.isEmpty()) {
                    QFile f(targetPath);
                    if (f.open(QIODevice::WriteOnly)) {
                        f.write(imgData);
                        f.close();

                        // Notify model on main thread
                        QMetaObject::invokeMethod(this, [id, this]() {
                            for (int i = 0; i < m_filteredEntries.size(); ++i) {
                                if (m_filteredEntries.at(i).id == id) {
                                    QModelIndex idx = index(i, 0);
                                    emit dataChanged(idx, idx, {ImagePathRole});
                                    break;
                                }
                            }
                        }, Qt::QueuedConnection);
                    }
                }
            }
        }
    });
}

void CliphistModel::applyFilter()
{
    beginResetModel();

    if (m_searchQuery.trimmed().isEmpty()) {
        m_filteredEntries = m_allEntries;
    } else {
        const QString q = m_searchQuery.toLower();
        m_filteredEntries.clear();
        for (const auto &entry : m_allEntries) {
            if (entry.label.toLower().contains(q)) {
                m_filteredEntries.append(entry);
            }
        }
    }

    endResetModel();
    emit countChanged();
}

void CliphistModel::copyItem(int index)
{
    if (index < 0 || index >= m_filteredEntries.size()) return;
    copyById(m_filteredEntries.at(index).id);
}

void CliphistModel::copyById(const QString &id)
{
    for (const auto &entry : m_allEntries) {
        if (entry.id == id) {
            QProcess *decodeProc = new QProcess();
            QProcess *wlCopyProc = new QProcess();

            decodeProc->setStandardOutputProcess(wlCopyProc);
            decodeProc->start(QStringLiteral("cliphist"), {QStringLiteral("decode")});
            wlCopyProc->start(QStringLiteral("wl-copy"));

            decodeProc->write((entry.rawLine + QLatin1Char('\n')).toUtf8());
            decodeProc->closeWriteChannel();

            connect(wlCopyProc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), [decodeProc, wlCopyProc]() {
                decodeProc->deleteLater();
                wlCopyProc->deleteLater();
            });
            break;
        }
    }
}

void CliphistModel::deleteItem(int index)
{
    if (index < 0 || index >= m_filteredEntries.size()) return;
    deleteById(m_filteredEntries.at(index).id);
}

void CliphistModel::deleteById(const QString &id)
{
    QString rawLine;
    QString imgPath;

    for (int i = 0; i < m_allEntries.size(); ++i) {
        if (m_allEntries.at(i).id == id) {
            rawLine = m_allEntries.at(i).rawLine;
            imgPath = m_allEntries.at(i).imagePath;
            m_allEntries.removeAt(i);
            break;
        }
    }

    if (!rawLine.isEmpty()) {
        QProcess *delProc = new QProcess();
        delProc->start(QStringLiteral("cliphist"), {QStringLiteral("delete")});
        delProc->write((rawLine + QLatin1Char('\n')).toUtf8());
        delProc->closeWriteChannel();
        connect(delProc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), [delProc]() {
            delProc->deleteLater();
        });

        if (!imgPath.isEmpty() && QFileInfo::exists(imgPath)) {
            QFile::remove(imgPath);
        }

        emit totalCountChanged();
        applyFilter();
    }
}

void CliphistModel::clearAll()
{
    QProcess::startDetached(QStringLiteral("cliphist"), {QStringLiteral("wipe")});

    beginResetModel();
    m_allEntries.clear();
    m_filteredEntries.clear();
    endResetModel();

    emit countChanged();
    emit totalCountChanged();

    // Clean cache directory
    QDir dir(m_cacheDir);
    const auto files = dir.entryInfoList(QDir::Files);
    for (const auto &file : files) {
        QFile::remove(file.absoluteFilePath());
    }
}

QVariantMap CliphistModel::get(int index) const
{
    if (index < 0 || index >= m_filteredEntries.size()) return QVariantMap();
    const auto &entry = m_filteredEntries.at(index);
    QVariantMap map;
    map[QStringLiteral("id")] = entry.id;
    map[QStringLiteral("clipId")] = entry.id;
    map[QStringLiteral("label")] = entry.label;
    map[QStringLiteral("isImage")] = entry.isImage;
    map[QStringLiteral("imagePath")] = entry.imagePath;
    map[QStringLiteral("rawLine")] = entry.rawLine;
    return map;
}

void CliphistModel::pruneCache()
{
    QDir dir(m_cacheDir);
    const auto files = dir.entryInfoList(QDir::Files);
    const QDateTime now = QDateTime::currentDateTime();

    for (const auto &file : files) {
        if (file.lastModified().daysTo(now) > 7) {
            QFile::remove(file.absoluteFilePath());
        }
    }
}
