#include "CliphistModel.h"
#include <QDir>
#include <QFileInfo>
#include <QImage>
#include <QSet>
#include <QThreadPool>
#include <algorithm>

namespace {
// QML delegates never show clipboard images above 500px, so cache downscaled
// copies instead of the full-resolution decode.
constexpr int kThumbMaxEdge = 512;

// Hard ceiling for the on-disk thumbnail cache: 32 MB at ~200 KB per 512px
// thumbnail holds far more images than any realistic cliphist history.
constexpr qint64 kCacheCapBytes = 32LL * 1024 * 1024;
}

CliphistModel::CliphistModel(QObject *parent)
    : QAbstractListModel(parent)
{
    m_cacheDir = QDir::homePath() + QStringLiteral("/.cache/ringo-shell/cliphist-imgs");
    QDir().mkpath(m_cacheDir);

    // Decode jobs run on a private 2-worker pool, so a burst of new images
    // cannot spike RSS.
    m_thumbPool = new QThreadPool(this);
    m_thumbPool->setMaxThreadCount(2);

    // No prune here: it needs the live entry list, which only exists after the
    // first `cliphist list` completes.
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
    if (!m_listProcess) return;

    // Pruning deletes every file whose id is missing from the list, so a failed
    // `cliphist list` must never be treated as "no entries".
    m_listValid = (exitStatus == QProcess::NormalExit && exitCode == 0);

    const QByteArray output = m_listProcess->readAllStandardOutput();
    m_listProcess->deleteLater();
    m_listProcess = nullptr;

    // Jobs are queued in the loop below and the counter decremented on the main
    // thread as each finishes.
    m_pendingThumbs = 0;

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
    pruneCache();
}

void CliphistModel::decodeThumbnail(const ClipEntry &entry)
{
    const QString rawLine = entry.rawLine;
    const QString targetPath = entry.imagePath;
    const QString id = entry.id;

    ++m_pendingThumbs;

    m_thumbPool->start([rawLine, targetPath, id, this]() {
        bool wrote = false;

        // `cliphist decode` piped into Qt, shrunk and stored as a PNG; no
        // external image tool involved.
        QProcess decode;
        decode.start(QStringLiteral("cliphist"), {QStringLiteral("decode")});
        if (decode.waitForStarted(1000)) {
            decode.write((rawLine + QLatin1Char('\n')).toUtf8());
            decode.closeWriteChannel();
            if (decode.waitForFinished(4000)) {
                const QByteArray imgData = decode.readAllStandardOutput();
                if (!imgData.isEmpty()) {
                    const QImage img = QImage::fromData(imgData);
                    if (!img.isNull()) {
                        // Shrink only, never upscale.
                        const QImage thumb =
                            (img.width() > kThumbMaxEdge || img.height() > kThumbMaxEdge)
                                ? img.scaled(kThumbMaxEdge, kThumbMaxEdge, Qt::KeepAspectRatio,
                                             Qt::SmoothTransformation)
                                : img;
                        const QString tmp = targetPath + QStringLiteral(".tmp");
                        if (thumb.save(tmp, "PNG")) {
                            QFile::remove(targetPath);
                            wrote = QFile::rename(tmp, targetPath);
                        } else {
                            QFile::remove(tmp);
                        }
                    }
                }
            }
        }

        if (!wrote) {
            // Never leave a truncated file: QML would show a broken image
            // instead of the text label.
            QFile::remove(targetPath);
        }

        // Notify on the main thread; the last job of a batch re-runs the prune.
        QMetaObject::invokeMethod(this, [id, wrote, this]() {
            if (wrote) {
                for (int i = 0; i < m_filteredEntries.size(); ++i) {
                    if (m_filteredEntries.at(i).id == id) {
                        const QModelIndex idx = index(i, 0);
                        emit dataChanged(idx, idx, {ImagePathRole});
                        break;
                    }
                }
            }
            if (m_pendingThumbs > 0 && --m_pendingThumbs == 0) {
                pruneCache();
            }
        }, Qt::QueuedConnection);
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
            QProcess *decodeProc = new QProcess(this);
            QProcess *wlCopyProc = new QProcess(this);

            decodeProc->setStandardOutputProcess(wlCopyProc);
            decodeProc->start(QStringLiteral("cliphist"), {QStringLiteral("decode")});
            wlCopyProc->start(QStringLiteral("wl-copy"));

            decodeProc->write((entry.rawLine + QLatin1Char('\n')).toUtf8());
            decodeProc->closeWriteChannel();

            const auto cleanup = [decodeProc, wlCopyProc]() {
                decodeProc->deleteLater();
                wlCopyProc->deleteLater();
            };
            connect(wlCopyProc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), cleanup);
            // A start failure never reaches `finished`, which would leave the
            // process alive for the shell's lifetime.
            connect(decodeProc, &QProcess::errorOccurred, cleanup);
            connect(wlCopyProc, &QProcess::errorOccurred, cleanup);
            break;
        }
    }
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
        QProcess *delProc = new QProcess(this);
        delProc->start(QStringLiteral("cliphist"), {QStringLiteral("delete")});
        delProc->write((rawLine + QLatin1Char('\n')).toUtf8());
        delProc->closeWriteChannel();
        const auto cleanup = [delProc]() { delProc->deleteLater(); };
        connect(delProc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), cleanup);
        // start() failing means `finished` never fires; the object must not linger.
        connect(delProc, &QProcess::errorOccurred, cleanup);

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
    // Never prune against an unknown/stale entry list (see onListProcessFinished).
    if (!m_listValid) return;

    QDir dir(m_cacheDir);
    const QFileInfoList files = dir.entryInfoList(QDir::Files);

    // Drop files whose entry is gone: `cliphist wipe` also runs outside this
    // model (the Mod+Shift+C keybind calls it directly).
    QSet<QString> liveIds;
    liveIds.reserve(m_allEntries.size());
    for (const ClipEntry &entry : m_allEntries) {
        if (entry.isImage) liveIds.insert(entry.id);
    }

    QFileInfoList kept;
    kept.reserve(files.size());
    qint64 totalBytes = 0;
    for (const QFileInfo &file : files) {
        if (!liveIds.contains(file.completeBaseName())) {
            QFile::remove(file.absoluteFilePath());
            continue;
        }
        totalBytes += file.size();
        kept.append(file);
    }

    // Evict the least recently written first.
    if (totalBytes > kCacheCapBytes) {
        std::sort(kept.begin(), kept.end(), [](const QFileInfo &a, const QFileInfo &b) {
            return a.lastModified() < b.lastModified();
        });
        for (const QFileInfo &file : kept) {
            if (totalBytes <= kCacheCapBytes) break;
            const qint64 size = file.size();
            if (QFile::remove(file.absoluteFilePath())) totalBytes -= size;
        }
    }
}
