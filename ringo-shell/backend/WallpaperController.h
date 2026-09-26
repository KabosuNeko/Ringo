#pragma once
#include <QElapsedTimer>
#include <QTimer>
#include <QObject>
#include <QString>
#include <QThread>
#include <QtQml/qqml.h>

// Owns the whole wallpaper pipeline: pywal palette regeneration, the blurred
// niri-backdrop image, and the in-process layer-shell renderer
// (backend/engines/wallpaper/wallpaper.c).
//
// The renderer owns a Wayland connection and a layer surface, so it runs on its
// own thread; switching wallpaper tears that thread down and starts a new one
// with the new image. Every step is asynchronous; the GUI thread is never
// blocked on wal, the blur or the renderer.
class WallpaperController final : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QString path READ path NOTIFY pathChanged)
    Q_PROPERTY(QString mode READ mode WRITE setMode NOTIFY modeChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
    Q_PROPERTY(bool slideshowEnabled READ slideshowEnabled WRITE setSlideshowEnabled NOTIFY slideshowEnabledChanged)
    Q_PROPERTY(int slideshowIntervalMinutes READ slideshowIntervalMinutes WRITE setSlideshowIntervalMinutes NOTIFY slideshowIntervalMinutesChanged)
    Q_PROPERTY(QString slideshowDir READ slideshowDir WRITE setSlideshowDir NOTIFY slideshowDirChanged)

public:
    explicit WallpaperController(QObject *parent = nullptr);
    ~WallpaperController() override;

    QString path() const { return m_path; }
    QString mode() const { return m_mode; }
    bool busy() const { return m_busy; }
    bool ready() const { return m_ready; }
    QString error() const { return m_error; }
    bool slideshowEnabled() const { return m_slideshowEnabled; }
    int slideshowIntervalMinutes() const { return m_slideshowIntervalMinutes; }
    QString slideshowDir() const { return m_slideshowDir; }

    // Valid values: fill, fit, spread, stretch, tile. Anything else is rejected
    // with `error` set, leaving the current mode untouched.
    void setMode(const QString &mode);

    // Rotates the wallpaper on a timer, picking a random image from
    // slideshowDir. `slideshowIntervalMinutes` <= 0 keeps the timer off.
    void setSlideshowEnabled(bool enabled);
    void setSlideshowIntervalMinutes(int minutes);
    void setSlideshowDir(const QString &dir);
    // Advances the slideshow immediately.
    Q_INVOKABLE void nextSlide();

    // Reads ~/.cache/wal/colors.json and applies its .wallpaper entry.
    Q_INVOKABLE void start();
    // Full pipeline for one file: wal -> blurred backdrop -> restart ringo-wallpaper.
    Q_INVOKABLE void apply(const QString &path);
    // Re-applies the current path.
    Q_INVOKABLE void reload();
    // Stops the wallpaper engine. The path is kept, so a later reload() revives it.
    Q_INVOKABLE void stop();

signals:
    void pathChanged();
    void modeChanged();
    void busyChanged();
    void readyChanged();
    void errorChanged();
    void slideshowEnabledChanged();
    void slideshowIntervalMinutesChanged();
    void slideshowDirChanged();
    void backdropChanged();

private:
    static QString engineBinary();
    static QString blurredPath();
    static QString walConfigPath();

    void setPath(const QString &path);
    void setReady(bool ready);
    void setBusy(bool busy);
    void setError(const QString &error);
    void setProcessId(qint64 pid);

    void runWal(const QString &path);
    void runBlur(const QString &path);
    void startEngine(const QString &path);
    void stopEngine();
    void reapLegacyEngines();
    void onEngineFinished(QThread *thread);
    void finishJob();
    void applySlideshow();
    QString pickRandomImage() const;

    QString m_path;
    QString m_mode = QStringLiteral("fill");
    QString m_error;
    QString m_pendingPath;   // apply() calls arriving while busy are coalesced
    bool m_slideshowEnabled = false;
    int m_slideshowIntervalMinutes = 30;
    QString m_slideshowDir;
    QTimer *m_slideTimer = nullptr;
    bool m_busy = false;
    bool m_ready = false;
    bool m_stopped = false;
    bool m_spawnWithMode = true;
    bool m_modeFallbackTried = false;
    int m_restarts = 0;
    QElapsedTimer m_engineAlive;      // how long the current engine has been up
    QThread *m_engineThread = nullptr; // resident wallpaper engine thread
};
