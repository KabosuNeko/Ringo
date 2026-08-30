#pragma once
#include <QObject>
#include <QTimer>
#include <QElapsedTimer>
#include <QHash>
#include <QDBusObjectPath>
#include <QtQml/qqml.h>

struct PlayerInfo {
    QString dbusName;
    QString track;
    QString artist;
    QString artUrl;
    QString playbackStatus; // Playing/Paused/Stopped
    qint64 lengthUs = 0; // microseconds
    qint64 positionUs = 0;
    qint64 positionUpdatedUs = 0; // when position was last fetched
    bool canPlay = false;
    bool canPause = false;
    bool canGoNext = false;
    bool canGoPrevious = false;
    bool canSeek = false;
};

class MprisController final : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QString track READ track NOTIFY trackChanged)
    Q_PROPERTY(QString artist READ artist NOTIFY artistChanged)
    Q_PROPERTY(QString artUrl READ artUrl NOTIFY artUrlChanged)
    Q_PROPERTY(bool playing READ playing NOTIFY playingChanged)
    Q_PROPERTY(bool hasPlayer READ hasPlayer NOTIFY hasPlayerChanged)
    Q_PROPERTY(double polledPosition READ polledPosition NOTIFY polledPositionChanged)
    Q_PROPERTY(double polledLength READ polledLength NOTIFY polledLengthChanged)
    Q_PROPERTY(double progress READ progress NOTIFY progressChanged)
    Q_PROPERTY(QString activePlayerDbusName READ activePlayerDbusName NOTIFY activePlayerDbusNameChanged)

public:
    explicit MprisController(QObject *parent = nullptr);

    QString track() const { return m_track; }
    QString artist() const { return m_artist; }
    QString artUrl() const { return m_artUrl; }
    bool playing() const { return m_playing; }
    bool hasPlayer() const { return m_hasPlayer; }
    double polledPosition() const { return m_polledPosition; }
    double polledLength() const { return m_polledLength; }
    double progress() const { return m_polledLength > 0 ? m_polledPosition / m_polledLength : 0; }
    QString activePlayerDbusName() const { return m_activePlayerDbusName; }

    Q_INVOKABLE void playPause();
    Q_INVOKABLE void next();
    Q_INVOKABLE void prev();
    Q_INVOKABLE void seek(double positionSeconds);
    Q_INVOKABLE void refresh();

signals:
    void trackChanged();
    void artistChanged();
    void artUrlChanged();
    void playingChanged();
    void hasPlayerChanged();
    void polledPositionChanged();
    void polledLengthChanged();
    void progressChanged();
    void activePlayerDbusNameChanged();
    void nowPlaying();

private slots:
    void handleNameOwnerChanged(const QString &name, const QString &oldOwner, const QString &newOwner);
    void handlePropertiesChanged(const QString &interface, const QVariantMap &changed, const QStringList &invalidated);
    void handleSeeked(qint64 position);
    void onTick();

private:
    void discoverPlayers();
    void addPlayer(const QString &name);
    void removePlayer(const QString &name);
    void updateActivePlayer();
    void setActivePlayer(const QString &name);
    void fetchPlayerState(const QString &name);
    void updatePolledValues();
    static QString artistFromMetadata(const QVariantMap &md);
    static QString trackFromMetadata(const QVariantMap &md);
    static QString artUrlFromMetadata(const QVariantMap &md);
    static qint64 lengthFromMetadata(const QVariantMap &md);
    void setTrack(const QString &v);
    void setArtist(const QString &v);
    void setArtUrl(const QString &v);
    void setPlaying(bool v);
    void setHasPlayer(bool v);
    void setPolledPosition(double v);
    void setPolledLength(double v);
    void setActivePlayerDbusName(const QString &v);

    QHash<QString, PlayerInfo> m_players;
    QString m_activePlayerDbusName;
    QString m_lastActiveDbusName;
    QString m_track;
    QString m_artist;
    QString m_artUrl;
    bool m_playing = false;
    bool m_hasPlayer = false;
    double m_polledPosition = 0;
    double m_polledLength = 0;
    bool m_wasPlaying = false;

    QTimer m_pollTimer;
    QElapsedTimer m_elapsed;
    qint64 m_positionBaseUs = 0;
    double m_positionBaseSec = 0;
};
