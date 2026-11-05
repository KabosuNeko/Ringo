#include "MprisController.h"
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusReply>
#include <QDBusMessage>
#include <QVariantMap>
#include <QDBusArgument>
#include <QDBusVariant>
#include <QUrl>
#include <QUrlQuery>

static inline QVariant unwrapDVariant(const QVariant &v) {
    if (v.userType() == qMetaTypeId<QDBusVariant>())
        return qvariant_cast<QDBusVariant>(v).variant();
    return v;
}

// Every call to a player is async: a hung player (a busy browser) must never
// freeze the shell's GUI thread.
static QDBusMessage playerMessage(const QString &service, const QString &interfaceName, const QString &method) {
    return QDBusMessage::createMethodCall(service, QStringLiteral("/org/mpris/MediaPlayer2"), interfaceName, method);
}

static QVariantMap toVariantMap(const QVariant &value) {
    const QVariant inner = value.userType() == qMetaTypeId<QDBusVariant>()
        ? qvariant_cast<QDBusVariant>(value).variant() : value;
    if (inner.userType() == qMetaTypeId<QDBusArgument>())
        return qdbus_cast<QVariantMap>(qvariant_cast<QDBusArgument>(inner));
    return inner.toMap();
}

void MprisController::setActive(bool v) {
    if (m_active == v) return;
    m_active = v;
    emit activeChanged();
    // Starts/stops the position timer right away instead of waiting for the
    // next D-Bus event.
    updateActivePlayer();
}

MprisController::MprisController(QObject *parent) : QObject(parent) {
    m_pollTimer.setInterval(500);
    m_pollTimer.setSingleShot(false);
    connect(&m_pollTimer, &QTimer::timeout, this, &MprisController::onTick);

    QDBusConnection bus = QDBusConnection::sessionBus();
    bus.connect(QStringLiteral("org.freedesktop.DBus"), QStringLiteral("/org/freedesktop/DBus"),
                QStringLiteral("org.freedesktop.DBus"), QStringLiteral("NameOwnerChanged"),
                this, SLOT(handleNameOwnerChanged(QString,QString,QString)));

    discoverPlayers();
    updateActivePlayer();
}

void MprisController::discoverPlayers() {
    QDBusConnection bus = QDBusConnection::sessionBus();
    auto *iface = bus.interface();
    if (!iface) return;
    QDBusReply<QStringList> reply = iface->registeredServiceNames();
    if (!reply.isValid()) return;
    for (const QString &name : reply.value()) {
        if (name.startsWith(QStringLiteral("org.mpris.MediaPlayer2."))) addPlayer(name);
    }
}

void MprisController::addPlayer(const QString &name) {
    if (m_players.contains(name)) return;
    PlayerInfo info; info.dbusName = name;
    if (QDBusConnectionInterface *busInterface = QDBusConnection::sessionBus().interface())
        info.uniqueName = busInterface->serviceOwner(name);
    m_players.insert(name, info);
    QDBusConnection::sessionBus().connect(name, QStringLiteral("/org/mpris/MediaPlayer2"),
        QStringLiteral("org.freedesktop.DBus.Properties"), QStringLiteral("PropertiesChanged"),
        this, SLOT(handlePropertiesChanged(QString,QVariantMap,QStringList)));
    QDBusConnection::sessionBus().connect(name, QStringLiteral("/org/mpris/MediaPlayer2"),
        QStringLiteral("org.mpris.MediaPlayer2.Player"), QStringLiteral("Seeked"),
        this, SLOT(handleSeeked(qint64)));
    fetchPlayerState(name);
    updateActivePlayer();
}

void MprisController::removePlayer(const QString &name) {
    if (!m_players.contains(name)) return;
    QDBusConnection::sessionBus().disconnect(name, QStringLiteral("/org/mpris/MediaPlayer2"),
        QStringLiteral("org.freedesktop.DBus.Properties"), QStringLiteral("PropertiesChanged"),
        this, SLOT(handlePropertiesChanged(QString,QVariantMap,QStringList)));
    QDBusConnection::sessionBus().disconnect(name, QStringLiteral("/org/mpris/MediaPlayer2"),
        QStringLiteral("org.mpris.MediaPlayer2.Player"), QStringLiteral("Seeked"),
        this, SLOT(handleSeeked(qint64)));
    m_players.remove(name);
    if (m_activePlayerDbusName == name) setActivePlayerDbusName(QString());
    updateActivePlayer();
}

void MprisController::handleNameOwnerChanged(const QString &name, const QString &oldOwner, const QString &newOwner) {
    if (!name.startsWith(QStringLiteral("org.mpris.MediaPlayer2."))) return;
    if (newOwner.isEmpty()) {
        removePlayer(name);
        return;
    }
    if (oldOwner.isEmpty()) {
        addPlayer(name);
        return;
    }

    // The well-known name moved between owners without passing through an
    // empty owner. Refresh the cached unique name so PropertiesChanged
    // signals from the new owner map to this player.
    auto it = m_players.find(name);
    if (it == m_players.end()) {
        addPlayer(name);
        return;
    }
    it->uniqueName = newOwner;
    fetchPlayerState(name);
    updateActivePlayer();
}

void MprisController::handlePropertiesChanged(const QString &interface, const QVariantMap &changed, const QStringList &) {
    if (interface != QStringLiteral("org.mpris.MediaPlayer2.Player")) return;

    QString target;
    if (calledFromDBus()) {
        const QString sender = message().service();
        if (!sender.isEmpty()) {
            for (auto it = m_players.cbegin(); it != m_players.cend(); ++it) {
                if (it->uniqueName == sender) { target = it.key(); break; }
            }
        }
    }


    if (target.isEmpty()) {
        // Never broadcast one player's delta to every player: a stale or
        // unknown unique name would corrupt the other players' state.
        return;
    }
    auto it = m_players.find(target);
    if (it == m_players.end()) return;
    applyProperties(*it, changed);
    updateActivePlayer();
}

void MprisController::handleSeeked(qint64 position) {
    // position in microseconds
    if (m_activePlayerDbusName.isEmpty()) return;
    auto it = m_players.find(m_activePlayerDbusName);
    if (it == m_players.end()) return;
    it->positionUs = position;
    m_positionBaseUs = position;
    m_positionBaseSec = position / 1e6;
    m_elapsed.restart();
    updatePolledValues();
}

void MprisController::fetchPlayerState(const QString &name) {
    QDBusMessage msg = playerMessage(name, QStringLiteral("org.freedesktop.DBus.Properties"), QStringLiteral("GetAll"));
    msg << QStringLiteral("org.mpris.MediaPlayer2.Player");
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(msg), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, name](QDBusPendingCallWatcher *w) {
        w->deleteLater();
        const QDBusPendingReply<QVariantMap> reply = *w;
        auto it = m_players.find(name); // the player may have left while we waited
        if (reply.isError() || it == m_players.end()) return;
        applyProperties(*it, reply.value());
        updateActivePlayer();
    });
}

// Shared by GetAll and PropertiesChanged: only the keys present are applied.
void MprisController::applyProperties(PlayerInfo &info, const QVariantMap &properties) {
    auto value = [&](const char *key) { return unwrapDVariant(properties.value(QLatin1String(key))); };
    if (properties.contains(QStringLiteral("PlaybackStatus"))) info.playbackStatus = value("PlaybackStatus").toString();
    if (properties.contains(QStringLiteral("Metadata"))) {
        const QVariantMap md = toVariantMap(properties.value(QStringLiteral("Metadata")));
        if (!md.isEmpty()) {
            info.track = trackFromMetadata(md);
            info.artist = artistFromMetadata(md);
            info.artUrl = artUrlFromMetadata(md);
            const qint64 len = lengthFromMetadata(md);
            if (len > 0) info.lengthUs = len;
            const QVariant tid = unwrapDVariant(md.value(QStringLiteral("mpris:trackid")));
            if (tid.userType() == qMetaTypeId<QDBusObjectPath>()) info.trackId = qvariant_cast<QDBusObjectPath>(tid).path();
            else if (tid.userType() == qMetaTypeId<QDBusArgument>()) info.trackId = qdbus_cast<QDBusObjectPath>(qvariant_cast<QDBusArgument>(tid)).path();
            else info.trackId = tid.toString();
        }
    }
    if (properties.contains(QStringLiteral("Position"))) info.positionUs = value("Position").toLongLong();
    if (properties.contains(QStringLiteral("CanPlay"))) info.canPlay = value("CanPlay").toBool();
    if (properties.contains(QStringLiteral("CanPause"))) info.canPause = value("CanPause").toBool();
    if (properties.contains(QStringLiteral("CanGoNext"))) info.canGoNext = value("CanGoNext").toBool();
    if (properties.contains(QStringLiteral("CanGoPrevious"))) info.canGoPrevious = value("CanGoPrevious").toBool();
    if (properties.contains(QStringLiteral("CanSeek"))) info.canSeek = value("CanSeek").toBool();
}

QString MprisController::trackFromMetadata(const QVariantMap &md) {
    return unwrapDVariant(md.value(QStringLiteral("xesam:title"))).toString();
}
QString MprisController::artistFromMetadata(const QVariantMap &md) {
    QVariant v = unwrapDVariant(md.value(QStringLiteral("xesam:artist")));
    if (v.canConvert<QStringList>()) {
        QStringList sl = v.toStringList();
        if (!sl.isEmpty()) return sl.join(QStringLiteral(", "));
    }
    QVariantList vl = v.toList();
    if (!vl.isEmpty()) {
        QStringList sl; for (auto &x : vl) sl << unwrapDVariant(x).toString(); return sl.join(QStringLiteral(", "));
    }
    if (v.userType() == qMetaTypeId<QDBusArgument>()) {
        QVariantList l = qdbus_cast<QVariantList>(qvariant_cast<QDBusArgument>(v));
        QStringList sl; for (auto &x : l) sl << unwrapDVariant(x).toString(); if (!sl.isEmpty()) return sl.join(QStringLiteral(", "));
    }
    return v.toString();
}
QString MprisController::artUrlFromMetadata(const QVariantMap &md) {
    QString art = unwrapDVariant(md.value(QStringLiteral("mpris:artUrl"))).toString();
    if (!art.isEmpty()) return art;
    // Firefox/YouTube often omits mpris:artUrl – derive YouTube thumbnail from xesam:url
    QVariant uv = unwrapDVariant(md.value(QStringLiteral("xesam:url")));
    QString urlStr = uv.toString();
    if (urlStr.contains(QStringLiteral("youtube.com/watch")) || urlStr.contains(QStringLiteral("youtu.be/"))) {
        QUrl url(urlStr);
        QString vid;
        if (url.host() == QStringLiteral("youtu.be")) {
            vid = url.path().mid(1);
        } else {
            QUrlQuery query(url);
            vid = query.queryItemValue(QStringLiteral("v"));
        }
        if (!vid.isEmpty()) return QStringLiteral("https://i.ytimg.com/vi/") + vid + QStringLiteral("/hqdefault.jpg");
    }
    return {};
}
qint64 MprisController::lengthFromMetadata(const QVariantMap &md) {
    QVariant v = unwrapDVariant(md.value(QStringLiteral("mpris:length")));
    if (!v.isValid()) return 0;
    bool ok=false; qint64 val = v.toLongLong(&ok);
    if (ok) return val;
    // try via QDBusArgument cast
    if (v.userType() == qMetaTypeId<QDBusArgument>()) {
        qint64 v2 = qdbus_cast<qint64>(qvariant_cast<QDBusArgument>(v));
        return v2;
    }
    return 0;
}

void MprisController::updateActivePlayer() {
    QString chosen;
    // prefer Playing
    for (auto it = m_players.begin(); it != m_players.end(); ++it) {
        if (it->playbackStatus == QStringLiteral("Playing")) { chosen = it.key(); break; }
    }
    if (chosen.isEmpty() && !m_lastActiveDbusName.isEmpty() && m_players.contains(m_lastActiveDbusName)) {
        auto it = m_players.find(m_lastActiveDbusName);
        if (it->playbackStatus == QStringLiteral("Paused")) chosen = m_lastActiveDbusName;
    }
    if (chosen.isEmpty()) {
        for (auto it = m_players.begin(); it != m_players.end(); ++it) {
            if (it->playbackStatus == QStringLiteral("Paused")) { chosen = it.key(); break; }
        }
    }
    if (chosen.isEmpty() && !m_players.isEmpty()) chosen = m_players.begin().key();
    if (chosen != m_activePlayerDbusName) setActivePlayer(chosen);
    else updatePolledValues();
}

void MprisController::setActivePlayer(const QString &name) {
    setActivePlayerDbusName(name);
    if (!name.isEmpty()) m_lastActiveDbusName = name;
    updatePolledValues();
}

void MprisController::updatePolledValues() {
    if (m_activePlayerDbusName.isEmpty() || !m_players.contains(m_activePlayerDbusName)) {
        setHasPlayer(false); setPlaying(false); setPolledPosition(0); setPolledLength(0);
        setTrack(QString()); setArtist(QString()); setArtUrl(QString());
        m_pollTimer.stop();
        return;
    }
    const PlayerInfo &info = m_players[m_activePlayerDbusName];
    bool isPlaying = info.playbackStatus == QStringLiteral("Playing");
    bool isPaused = info.playbackStatus == QStringLiteral("Paused");
    bool hasPlayer = isPlaying || isPaused;
    setHasPlayer(hasPlayer);
    setPlaying(isPlaying);
    setTrack(info.track);
    setArtist(info.artist);
    setArtUrl(info.artUrl);
    double lenSec = info.lengthUs / 1e6;
    // some players (fork bug) report length <= position, so keep length as is
    if (lenSec <= 0) lenSec = 0;
    setPolledLength(lenSec);
    // position with elapsed
    qint64 baseUs = info.positionUs;
    double baseSec = baseUs / 1e6;
    if (isPlaying && m_active) {
        if (!m_pollTimer.isActive()) { m_positionBaseUs = baseUs; m_positionBaseSec = baseSec; m_elapsed.restart(); m_pollTimer.start(); }
        else {
            // if base changed externally, reset elapsed
            if (qAbs(baseUs - m_positionBaseUs) > 1000000) { m_positionBaseUs = baseUs; m_positionBaseSec = baseSec; m_elapsed.restart(); }
        }
        double elapsed = m_elapsed.elapsed() / 1000.0;
        double pos = m_positionBaseSec + elapsed;
        if (lenSec > 0 && pos > lenSec) pos = lenSec;
        setPolledPosition(pos);
    } else {
        m_pollTimer.stop();
        setPolledPosition(baseSec);
    }
    if (m_wasPlaying != isPlaying) {
        m_wasPlaying = isPlaying;
        if (isPlaying) emit nowPlaying();
    }
}

void MprisController::onTick() { updatePolledValues(); }

void MprisController::setTrack(const QString &v) { if (m_track==v) return; m_track=v; emit trackChanged(); }
void MprisController::setArtist(const QString &v) { if (m_artist==v) return; m_artist=v; emit artistChanged(); }
void MprisController::setArtUrl(const QString &v) { if (m_artUrl==v) return; m_artUrl=v; emit artUrlChanged(); }
void MprisController::setPlaying(bool v) { if (m_playing==v) return; m_playing=v; emit playingChanged(); }
void MprisController::setHasPlayer(bool v) { if (m_hasPlayer==v) return; m_hasPlayer=v; emit hasPlayerChanged(); }
void MprisController::setPolledPosition(double v) { if (qFuzzyCompare(m_polledPosition+1, v+1)) return; m_polledPosition=v; emit polledPositionChanged(); emit progressChanged(); }
void MprisController::setPolledLength(double v) { if (qFuzzyCompare(m_polledLength+1, v+1)) return; m_polledLength=v; emit polledLengthChanged(); emit progressChanged(); }
void MprisController::setActivePlayerDbusName(const QString &v) { if (m_activePlayerDbusName==v) return; m_activePlayerDbusName=v; }

void MprisController::callPlayer(const QString &method, const QVariantList &args) {
    if (m_activePlayerDbusName.isEmpty()) return;
    QDBusMessage msg = playerMessage(m_activePlayerDbusName, QStringLiteral("org.mpris.MediaPlayer2.Player"), method);
    msg.setArguments(args);
    QDBusConnection::sessionBus().send(msg); // fire and forget: state comes back via PropertiesChanged
}

void MprisController::playPause() { callPlayer(QStringLiteral("PlayPause")); }
void MprisController::next() { callPlayer(QStringLiteral("Next")); }
void MprisController::prev() { callPlayer(QStringLiteral("Previous")); }
void MprisController::stop() { callPlayer(QStringLiteral("Stop")); }
void MprisController::seek(double positionSeconds) {
    auto it = m_players.find(m_activePlayerDbusName);
    if (it == m_players.end() || !it->canSeek) return;
    const qint64 us = qint64(positionSeconds * 1e6);
    const QString trackId = it->trackId.isEmpty()
        ? QStringLiteral("/org/mpris/MediaPlayer2/TrackList/NoTrack") : it->trackId;
    callPlayer(QStringLiteral("SetPosition"), {QVariant::fromValue(QDBusObjectPath(trackId)), us});
    m_positionBaseUs = us; m_positionBaseSec = positionSeconds; m_elapsed.restart();
    updatePolledValues();
}
