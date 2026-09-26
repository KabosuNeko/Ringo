#include "WallpaperController.h"

#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QImage>
#include <QImageReader>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QRandomGenerator>
#include <QScreen>
#include <QThreadPool>
#include <QTimer>
#include <QUrl>
#include <algorithm>
#include <cmath>
#include <functional>
#include <csignal>
#include <memory>
#include <sys/types.h>

#include "engines/wallpaper/wallpaper.h"

#include "StateStore.h"

namespace {

constexpr int kEngineWaitMs = 2000;
constexpr int kStopAttempts = 4;
constexpr int kEngineRestartDelayMs = 1000;
constexpr qint64 kImmediateExitMs = 2000;

// A QThread must never be destroyed while it is still running: Qt treats that
// as fatal. Ask the engine to return, wait, and if it refuses, hand the object
// over to the event loop instead of deleting it here.
bool stopThread(QThread *thread, const std::function<void()> &requestStop) {
    for (int attempt = 0; attempt < kStopAttempts; ++attempt) {
        requestStop();
        if (thread->wait(kEngineWaitMs)) {
            thread->deleteLater();
            return true;
        }
    }

    QObject::connect(thread, &QThread::finished, thread, &QObject::deleteLater);
    thread->setParent(nullptr);
    return false;
}

QString stderrTail(const QByteArray &output) {
    const QByteArray trimmed = output.right(400).trimmed();
    if (trimmed.isEmpty()) return QStringLiteral("(no output)");
    return QString::fromUtf8(trimmed);
}

/* The engine blocks in its own Wayland event loop, so it owns a thread. stop()
 * is asynchronous: it wakes the loop through the engine's self-pipe, and the
 * loop disconnects and returns by itself.
 *
 * The decode runs on this thread too: Qt is the process's only image decoder,
 * and the engine takes the decoded pixels rather than a path. */
class EngineThread final : public QThread {
public:
    EngineThread(const QString &mode, const QString &path, QObject *parent = nullptr)
        : QThread(parent), m_mode(mode.toUtf8()), m_path(path) {}

    void stop() { ringo_wallpaper_stop(); }
    QString error() const { return m_error; }

protected:
    void run() override {
        QImageReader reader(m_path);
        if (!reader.canRead()) {
            m_error = QStringLiteral("cannot read %1: %2")
                          .arg(m_path, reader.errorString());
            return;
        }

        // tile repeats the image at its own size, so downscaling it would change
        // what the mode means; every other mode scales per output anyway.
        const bool nativePixels = m_mode == QByteArrayLiteral("tile");
        const QSize screen = nativePixels ? QSize() : largestScreen();
        const QSize full = reader.size();
        if (screen.isValid() && full.width() > 0 && full.height() > 0) {
            // Cover the largest screen like PreserveAspectCrop: everything
            // smaller would be upscaled by the engine, everything larger would
            // only make the shell hold pixels no output can show.
            const double scale = std::max(double(screen.width()) / full.width(),
                                          double(screen.height()) / full.height());
            if (scale < 1.0)
                reader.setScaledSize(QSize(std::max(1, int(std::ceil(full.width() * scale))),
                                           std::max(1, int(std::ceil(full.height() * scale)))));
        }

        // m_image owns the pixels: the engine reads that buffer for the whole
        // run, so it must outlive ringo_wallpaper_run() and is dropped right
        // after it returns.
        const QImage decoded = reader.read();
        if (decoded.isNull()) {
            m_error = QStringLiteral("cannot decode %1: %2")
                          .arg(m_path, reader.errorString());
            return;
        }
        m_image = decoded.convertToFormat(QImage::Format_RGBA8888);
        if (m_image.isNull()) {
            m_error = QStringLiteral("cannot convert %1 to RGBA8888")
                          .arg(m_path);
            return;
        }

        const struct ringo_wallpaper_image image = {
            m_image.constBits(), m_image.width(), m_image.height()};

        // The QByteArray keeps the mode string alive for the whole run.
        const int rc = ringo_wallpaper_run(m_mode.isEmpty() ? nullptr : m_mode.constData(),
                                           &image);
        m_image = QImage();
        if (rc != 0) m_error = QString::fromLocal8Bit(ringo_wallpaper_error());
    }

private:
    // The largest screen in device pixels. Empty when the shell reports no
    // screens, in which case the image is decoded at its full size.
    static QSize largestScreen() {
        QSize largest;
        for (const QScreen *screen : QGuiApplication::screens())
            largest = largest.expandedTo(screen->geometry().size()
                                             * screen->devicePixelRatio());
        return largest;
    }

    QByteArray m_mode;
    QString m_path;
    QImage m_image;
    QString m_error;
};

} // namespace

namespace {
const QString kModeKey = QStringLiteral("wallpaper.mode");
const QString kSlideshowKey = QStringLiteral("wallpaper.slideshow");
const QStringList kModes = {QStringLiteral("fill"), QStringLiteral("fit"),
                            QStringLiteral("spread"), QStringLiteral("stretch"),
                            QStringLiteral("tile")};
const QStringList kImageFilters = {QStringLiteral("*.png"), QStringLiteral("*.jpg"),
                                   QStringLiteral("*.jpeg"), QStringLiteral("*.webp"),
                                   QStringLiteral("*.bmp")};
} // namespace

WallpaperController::WallpaperController(QObject *parent) : QObject(parent) {
    const QString mode = StateStore::instance().get(kModeKey).toString();
    if (kModes.contains(mode)) m_mode = mode;
    m_slideshowEnabled = StateStore::instance().get(kSlideshowKey, false).toBool();

    m_slideTimer = new QTimer(this);
    connect(m_slideTimer, &QTimer::timeout, this, &WallpaperController::nextSlide);
}

WallpaperController::~WallpaperController() {
    // A Quickshell config reload destroys and recreates the singleton; stop the
    // engine thread instead of leaving it drawing behind the new instance.
    stopEngine();
}

QString WallpaperController::blurredPath() {
    return QDir::homePath() + QStringLiteral("/.cache/wal/wallpaper_blurred.jpg");
}

QString WallpaperController::walConfigPath() {
    return QDir::homePath() + QStringLiteral("/.cache/wal/colors.json");
}

void WallpaperController::setPath(const QString &path) {
    if (m_path == path) return;
    m_path = path;
    emit pathChanged();
}

void WallpaperController::setReady(bool ready) {
    if (m_ready == ready) return;
    m_ready = ready;
    emit readyChanged();
}

void WallpaperController::setBusy(bool busy) {
    if (m_busy == busy) return;
    m_busy = busy;
    emit busyChanged();
}

void WallpaperController::setError(const QString &error) {
    if (m_error == error) return;
    m_error = error;
    emit errorChanged();
}

void WallpaperController::setMode(const QString &mode) {
    if (!kModes.contains(mode)) {
        setError(QStringLiteral("invalid wallpaper mode: %1 (expected one of %2)")
                     .arg(mode, kModes.join(QStringLiteral(", "))));
        return;
    }
    if (m_mode == mode) return;
    m_mode = mode;
    emit modeChanged();
    StateStore::instance().set(kModeKey, mode);
}

void WallpaperController::setSlideshowEnabled(bool enabled) {
    if (m_slideshowEnabled == enabled) return;
    m_slideshowEnabled = enabled;
    emit slideshowEnabledChanged();
    StateStore::instance().set(kSlideshowKey, enabled);
    applySlideshow();
}

void WallpaperController::setSlideshowIntervalMinutes(int minutes) {
    if (m_slideshowIntervalMinutes == minutes) return;
    m_slideshowIntervalMinutes = minutes;
    emit slideshowIntervalMinutesChanged();
    applySlideshow();
}

void WallpaperController::setSlideshowDir(const QString &dir) {
    // config.jsonc is written by hand, so "~/Pictures/Wallpapers" has to work
    // here exactly like it does in the wallpaper switcher.
    QString normalized = dir;
    if (normalized.startsWith(QStringLiteral("~/")))
        normalized = QDir::homePath() + normalized.mid(1);
    if (m_slideshowDir == normalized) return;
    m_slideshowDir = normalized;
    emit slideshowDirChanged();
    applySlideshow();
}

void WallpaperController::applySlideshow() {
    if (m_slideshowEnabled && m_slideshowIntervalMinutes > 0 && !m_slideshowDir.isEmpty()) {
        m_slideTimer->start(m_slideshowIntervalMinutes * 60 * 1000);
    } else {
        m_slideTimer->stop();
    }
}

void WallpaperController::nextSlide() {
    if (m_busy) return;  // the running pipeline will not pick up a second image

    const QString next = pickRandomImage();
    if (next.isEmpty()) {
        setError(QStringLiteral("no image to show from %1").arg(m_slideshowDir));
        return;
    }
    apply(next);
}

QString WallpaperController::pickRandomImage() const {
    if (m_slideshowDir.isEmpty()) return QString();

    QStringList candidates;
    QDirIterator it(m_slideshowDir, kImageFilters, QDir::Files, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        const QString path = it.next();
        if (path != m_path) candidates.append(path);
    }
    if (candidates.isEmpty()) return QString();

    return candidates.at(QRandomGenerator::global()->bounded(candidates.size()));
}

void WallpaperController::start() {
    // Older Ringo releases ran the wallpaper engine as a standalone process; a
    // shell that died without cleaning up would leave one behind, drawing a
    // stale wallpaper on top of ours. The engine is in-process now, so any
    // leftover of that design has to go.
    reapLegacyEngines();

    QFile config(walConfigPath());
    if (!config.open(QIODevice::ReadOnly)) {
        setError(QStringLiteral("cannot read %1").arg(walConfigPath()));
        return;
    }

    const QJsonDocument doc = QJsonDocument::fromJson(config.readAll());
    const QString wallpaper = doc.object().value(QStringLiteral("wallpaper")).toString();
    if (wallpaper.isEmpty()) {
        setError(QStringLiteral("no .wallpaper entry in %1").arg(walConfigPath()));
        return;
    }
    if (!QFileInfo::exists(wallpaper)) {
        setError(QStringLiteral("wallpaper from %1 does not exist: %2").arg(walConfigPath(), wallpaper));
        return;
    }

    apply(wallpaper);
}

void WallpaperController::apply(const QString &path) {
    if (m_busy) {
        // Coalesce: the running pipeline picks this up when it finishes.
        m_pendingPath = path;
        return;
    }

    QString target = path;
    if (target.startsWith(QStringLiteral("file://"))) target = QUrl(target).toLocalFile();
    if (target.startsWith(QStringLiteral("~/"))) target = QDir::homePath() + target.mid(1);

    const QFileInfo info(target);
    if (!info.exists() || !info.isFile()) {
        setError(QStringLiteral("wallpaper not found: %1").arg(target));
        return;
    }

    m_pendingPath.clear();
    m_stopped = false;
    m_restarts = 0;
    m_modeFallbackTried = false;
    setPath(info.absoluteFilePath());
    setError(QString());

    setBusy(true);
    runWal(m_path);
}

void WallpaperController::reload() {
    if (m_path.isEmpty()) {
        setError(QStringLiteral("no wallpaper to reload"));
        return;
    }
    apply(m_path);
}

void WallpaperController::stop() {
    m_stopped = true;
    m_pendingPath.clear();
    stopEngine();
}

void WallpaperController::runWal(const QString &path) {
    QProcess *proc = new QProcess(this);
    proc->setProcessChannelMode(QProcess::MergedChannels);

    auto done = std::make_shared<bool>(false);
    auto next = [this, proc, path, done](int code, bool failedToStart) {
        if (*done) return;
        *done = true;
        const QByteArray output = proc->readAll();
        proc->deleteLater();

        if (failedToStart || code != 0) {
            const QString reason = failedToStart
                ? QStringLiteral("could not start")
                : QStringLiteral("exit code %1").arg(code);
            setError(QStringLiteral("wal -i %1 -q -n -e failed (%2): %3").arg(path, reason, stderrTail(output)));
        }
        runBlur(path);
    };

    connect(proc, &QProcess::finished, this, [next](int code, QProcess::ExitStatus) { next(code, false); });
    connect(proc, &QProcess::errorOccurred, this, [next](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) next(-1, true);
    });

    proc->start(QStringLiteral("wal"), {QStringLiteral("-i"), path, QStringLiteral("-q"), QStringLiteral("-n"),
                                        QStringLiteral("-e")});
}

namespace {
// Three box-blur passes of width 12 approximate a Gaussian: the variance of one
// box of width w is (w^2-1)/12, so three of them give sigma = sqrt(3*(w^2-1)/12)
// = 5.98 for w = 12 - matching the `-blur 0x6` the ImageMagick pipeline applied
// in the 25% space, which is why the blur can move in-process unnoticed.
constexpr int kBlurBoxWidth = 12;
constexpr int kBlurPasses = 3;
constexpr int kBlurTargetWidth = 1920;
constexpr int kBlurTargetHeight = 1080;
constexpr int kBlurJpegQuality = 90;

void blurRows(QImage &img) {
    const int w = img.width();
    const int h = img.height();
    if (w < 2) return;
    constexpr int left = (kBlurBoxWidth - 1) / 2;    // 5
    constexpr int right = kBlurBoxWidth - 1 - left;  // 6
    QImage out(img.size(), img.format());
    for (int y = 0; y < h; ++y) {
        const QRgb *row = reinterpret_cast<const QRgb *>(img.constScanLine(y));
        QRgb *dst = reinterpret_cast<QRgb *>(out.scanLine(y));
        int r = 0, g = 0, b = 0, a = 0;
        for (int i = -left; i <= right; ++i) {
            const QRgb p = row[std::clamp(i, 0, w - 1)];
            r += qRed(p); g += qGreen(p); b += qBlue(p); a += qAlpha(p);
        }
        for (int x = 0; x < w; ++x) {
            dst[x] = qRgba(r / kBlurBoxWidth, g / kBlurBoxWidth, b / kBlurBoxWidth,
                           a / kBlurBoxWidth);
            const QRgb drop = row[std::clamp(x - left, 0, w - 1)];
            const QRgb add = row[std::clamp(x + right + 1, 0, w - 1)];
            r += qRed(add) - qRed(drop);
            g += qGreen(add) - qGreen(drop);
            b += qBlue(add) - qBlue(drop);
            a += qAlpha(add) - qAlpha(drop);
        }
    }
    img = out;
}

void blurColumns(QImage &img) {
    const int w = img.width();
    const int h = img.height();
    if (h < 2) return;
    constexpr int left = (kBlurBoxWidth - 1) / 2;
    constexpr int right = kBlurBoxWidth - 1 - left;
    QImage out(img.size(), img.format());
    for (int x = 0; x < w; ++x) {
        int r = 0, g = 0, b = 0, a = 0;
        for (int i = -left; i <= right; ++i) {
            const QRgb p = reinterpret_cast<const QRgb *>(img.constScanLine(std::clamp(i, 0, h - 1)))[x];
            r += qRed(p); g += qGreen(p); b += qBlue(p); a += qAlpha(p);
        }
        for (int y = 0; y < h; ++y) {
            reinterpret_cast<QRgb *>(out.scanLine(y))[x] =
                qRgba(r / kBlurBoxWidth, g / kBlurBoxWidth, b / kBlurBoxWidth, a / kBlurBoxWidth);
            const QRgb drop = reinterpret_cast<const QRgb *>(img.constScanLine(std::clamp(y - left, 0, h - 1)))[x];
            const QRgb add = reinterpret_cast<const QRgb *>(img.constScanLine(std::clamp(y + right + 1, 0, h - 1)))[x];
            r += qRed(add) - qRed(drop);
            g += qGreen(add) - qGreen(drop);
            b += qBlue(add) - qBlue(drop);
            a += qAlpha(add) - qAlpha(drop);
        }
    }
    img = out;
}

// Reproduces `magick <src> -resize 25% -blur 0x6 -resize 1920x1080^ -gravity
// center -extent 1920x1080 <target>` without ImageMagick.
bool writeBlurredWallpaper(const QString &source, const QString &target, QString *error) {
    const QImage src(source);
    if (src.isNull()) {
        *error = QStringLiteral("could not load %1").arg(source);
        return false;
    }

    QImage small = src.convertToFormat(QImage::Format_ARGB32)
                       .scaled(std::max(1, src.width() / 4), std::max(1, src.height() / 4),
                               Qt::IgnoreAspectRatio, Qt::SmoothTransformation);
    for (int i = 0; i < kBlurPasses; ++i) {
        blurRows(small);
        blurColumns(small);
    }

    QImage big = small.scaled(kBlurTargetWidth, kBlurTargetHeight, Qt::KeepAspectRatioByExpanding,
                              Qt::SmoothTransformation);
    big = big.copy((big.width() - kBlurTargetWidth) / 2, (big.height() - kBlurTargetHeight) / 2,
                   kBlurTargetWidth, kBlurTargetHeight);

    // Write beside the target and rename, so Backdrop's file watcher can never
    // observe a half-written JPEG.
    const QString tmp = target + QStringLiteral(".tmp");
    if (!big.save(tmp, "JPG", kBlurJpegQuality)) {
        QFile::remove(tmp);
        *error = QStringLiteral("could not write %1").arg(target);
        return false;
    }
    QFile::remove(target);
    if (!QFile::rename(tmp, target)) {
        QFile::remove(tmp);
        *error = QStringLiteral("could not replace %1").arg(target);
        return false;
    }
    return true;
}
}  // namespace

void WallpaperController::runBlur(const QString &path) {
    const QString out = blurredPath();

    // Off the GUI thread: decoding and blurring a 1080p wallpaper is a few
    // milliseconds of CPU that the shell must not spend on the event loop.
    QThreadPool::globalInstance()->start([this, path, out]() {
        QString error;
        const bool ok = writeBlurredWallpaper(path, out, &error);
        QMetaObject::invokeMethod(
            this,
            [this, path, ok, error]() {
                if (!ok) {
                    setError(QStringLiteral("blurring %1 failed: %2").arg(path, error));
                } else {
                    emit backdropChanged();
                }
                startEngine(path);
            },
            Qt::QueuedConnection);
    });
}

void WallpaperController::startEngine(const QString &path) {
    if (m_stopped) {
        finishJob();
        return;
    }

    stopEngine();  // a replaced engine is not an unexpected exit

    EngineThread *thread = new EngineThread(m_spawnWithMode ? m_mode : QString(), path, this);
    m_engineThread = thread;

    connect(thread, &QThread::started, this, [this, thread] {
        if (thread != m_engineThread) return;
        m_engineAlive.start();
        setReady(true);
    });
    connect(thread, &QThread::finished, this, [this, thread] { onEngineFinished(thread); });

    thread->start();
    finishJob();
}

void WallpaperController::onEngineFinished(QThread *thread) {
    if (thread != m_engineThread) {
        // A replaced engine: stopEngine() detached it before waking it, so this
        // exit is expected and must not touch the engine that replaced it.
        if (thread) thread->deleteLater();
        return;
    }

    const QString engineError =
        thread ? static_cast<EngineThread *>(thread)->error() : QString();
    if (thread) thread->deleteLater();
    m_engineThread = nullptr;
    setReady(false);

    if (m_stopped) return;

    // A mode this engine build rejects dies immediately; retry without it rather
    // than leaving no wallpaper at all. A run that survived a while and then
    // stopped is a real failure: retrying it without the mode would silently
    // drop the mode.
    const bool diedImmediately = m_engineAlive.isValid()
        && m_engineAlive.elapsed() < kImmediateExitMs;
    if (diedImmediately && m_spawnWithMode && !m_modeFallbackTried) {
        m_modeFallbackTried = true;
        startEngine(m_path);
        return;
    }

    if (m_restarts < 1 && !m_path.isEmpty() && QFileInfo::exists(m_path)) {
        m_restarts++;
        const QString path = m_path;
        QTimer::singleShot(kEngineRestartDelayMs, this, [this, path] {
            if (!m_engineThread && !m_stopped) startEngine(path);
        });
        return;
    }

    setError(engineError.isEmpty()
                 ? QStringLiteral("the wallpaper engine stopped unexpectedly")
                 : QStringLiteral("the wallpaper engine failed: %1").arg(engineError));
}

void WallpaperController::stopEngine() {
    auto *thread = static_cast<EngineThread *>(m_engineThread);
    if (!thread) return;

    // Detach first: the exit of a replaced engine is not an unexpected one, so
    // its finished handler must not run the supervision path.
    m_engineThread = nullptr;
    setReady(false);

    if (!stopThread(thread, [thread] { thread->stop(); })) {
        setError(QStringLiteral(
            "the wallpaper engine did not stop; its thread is left to finish on its own"));
    }
}

void WallpaperController::reapLegacyEngines() {
    // Older Ringo releases ran the engine as a process; reap any leftover so an
    // upgrade cannot leave a stale renderer drawing over ours.
    QDir procDir(QStringLiteral("/proc"));
    const QStringList entries = procDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &entry : entries) {
        bool isPid = false;
        const qint64 pid = entry.toLongLong(&isPid);
        if (!isPid) continue;

        QFile cmdline(QStringLiteral("/proc/%1/cmdline").arg(entry));
        if (!cmdline.open(QIODevice::ReadOnly)) continue;
        const QByteArray raw = cmdline.readAll();
        const int nul = raw.indexOf('\0');
        const QByteArray argv0 = nul >= 0 ? raw.left(nul) : raw;
        const QString name = QFileInfo(QString::fromLocal8Bit(argv0)).fileName();
        if (name != QStringLiteral("ringo-wallpaper")) continue;

        ::kill(static_cast<pid_t>(pid), SIGTERM);
    }
}

void WallpaperController::finishJob() {
    setBusy(false);
    if (!m_pendingPath.isEmpty() && !m_stopped) {
        const QString next = m_pendingPath;
        m_pendingPath.clear();
        apply(next);
    }
}
