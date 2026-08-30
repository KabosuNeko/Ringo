#include "MprisController.h"
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDBusMessage>
#include <QVariantMap>
#include <QDBusArgument>
#include <QDBusVariant>
#include <QDebug>

static inline QVariant unwrapDVariant(const QVariant &v) {
    if (v.userType() == qMetaTypeId<QDBusVariant>())
        return qvariant_cast<QDBusVariant>(v).variant();
    return v;
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
    if (newOwner.isEmpty()) removePlayer(name);
    else if (oldOwner.isEmpty()) addPlayer(name);
}

void MprisController::handlePropertiesChanged(const QString &interface, const QVariantMap &changed, const QStringList &) {
    if (interface != QStringLiteral("org.mpris.MediaPlayer2.Player")) return;
    Q_UNUSED(changed)
    for (auto it = m_players.begin(); it != m_players.end(); ++it) fetchPlayerState(it.key());
    updateActivePlayer();
    updatePolledValues();
}

void MprisController::handleSeeked(qint64 position) {
    // position in microseconds
    if (m_activePlayerDbusName.isEmpty()) return;
    auto it = m_players.find(m_activePlayerDbusName);
    if (it == m_players.end()) return;
    it->positionUs = position;
    it->positionUpdatedUs = 0;
    m_positionBaseUs = position;
    m_positionBaseSec = position / 1e6;
    m_elapsed.restart();
    updatePolledValues();
}

void MprisController::fetchPlayerState(const QString &name) {
    auto it = m_players.find(name);
    if (it == m_players.end()) return;
    QDBusInterface iface(name, QStringLiteral("/org/mpris/MediaPlayer2"), QStringLiteral("org.freedesktop.DBus.Properties"), QDBusConnection::sessionBus());
    if (!iface.isValid()) return;
    auto get = [&](const QString &ifaceName, const QString &prop) -> QVariant {
        QDBusReply<QVariant> r = iface.call(QStringLiteral("Get"), ifaceName, prop);
        if (!r.isValid()) return {};
        return unwrapDVariant(r.value());
    };
    // PlaybackStatus
    QVariant vStatus = get(QStringLiteral("org.mpris.MediaPlayer2.Player"), QStringLiteral("PlaybackStatus"));
    if (vStatus.isValid()) it->playbackStatus = unwrapDVariant(vStatus).toString();
    QVariant vMeta = get(QStringLiteral("org.mpris.MediaPlayer2.Player"), QStringLiteral("Metadata"));
    QVariantMap md;
    if (vMeta.isValid()) {
        QVariant inner = unwrapDVariant(vMeta);
        if (inner.canConvert<QVariantMap>()) {
            // Metadata outer map may contain QDBusVariant values; qdbus_cast handles inner variants
            if (inner.userType() == qMetaTypeId<QDBusArgument>()) md = qdbus_cast<QVariantMap>(qvariant_cast<QDBusArgument>(inner));
            else md = qdbus_cast<QVariantMap>(inner);
            if (md.isEmpty()) md = inner.toMap();
        } else {
            md = qdbus_cast<QVariantMap>(inner);
            if (md.isEmpty()) md = inner.toMap();
        }
    }
    if (!md.isEmpty()) {
        it->track = trackFromMetadata(md);
        it->artist = artistFromMetadata(md);
        it->artUrl = artUrlFromMetadata(md);
        qint64 len = lengthFromMetadata(md);
        if (len > 0) it->lengthUs = len;
    }
    QVariant vPos = get(QStringLiteral("org.mpris.MediaPlayer2.Player"), QStringLiteral("Position"));
    if (vPos.isValid()) {
        qint64 pos = unwrapDVariant(vPos).toLongLong();
        it->positionUs = pos;
        it->positionUpdatedUs = 0;
    }
    // Can* properties
    QVariant vCanPlay = get(QStringLiteral("org.mpris.MediaPlayer2.Player"), QStringLiteral("CanPlay"));
    if (vCanPlay.isValid()) it->canPlay = unwrapDVariant(vCanPlay).toBool();
    QVariant vCanPause = get(QStringLiteral("org.mpris.MediaPlayer2.Player"), QStringLiteral("CanPause"));
    if (vCanPause.isValid()) it->canPause = unwrapDVariant(vCanPause).toBool();
    QVariant vCanNext = get(QStringLiteral("org.mpris.MediaPlayer2.Player"), QStringLiteral("CanGoNext"));
    if (vCanNext.isValid()) it->canGoNext = unwrapDVariant(vCanNext).toBool();
    QVariant vCanPrev = get(QStringLiteral("org.mpris.MediaPlayer2.Player"), QStringLiteral("CanGoPrevious"));
    if (vCanPrev.isValid()) it->canGoPrevious = unwrapDVariant(vCanPrev).toBool();
    QVariant vCanSeek = get(QStringLiteral("org.mpris.MediaPlayer2.Player"), QStringLiteral("CanSeek"));
    if (vCanSeek.isValid()) it->canSeek = unwrapDVariant(vCanSeek).toBool();
}

QString MprisController::trackFromMetadata(const QVariantMap &md) {
    auto v = md.value(QStringLiteral("xesam:title"));
    v = unwrapDVariant(v);
    if (!v.isValid() || v.toString().isEmpty()) {
        auto v2 = md.value(QStringLiteral("xesam:title"));
        v = unwrapDVariant(v2);
    }
    return v.toString();
}
QString MprisController::artistFromMetadata(const QVariantMap &md) {
    QVariant v = unwrapDVariant(md.value(QStringLiteral("xesam:artist")));
    if (v.userType() == QMetaType::QStringList || v.typeId() == QMetaType::QStringList) return v.toStringList().join(QStringLiteral(", "));
    if (v.canConvert<QStringList>()) {
        QStringList sl = v.toStringList();
        if (!sl.isEmpty()) return sl.join(QStringLiteral(", "));
    }
    if (v.userType() == qMetaTypeId<QDBusArgument>()) {
        QVariantList l = qdbus_cast<QVariantList>(qvariant_cast<QDBusArgument>(v));
        QStringList sl; for (auto &x : l) sl << unwrapDVariant(x).toString(); if (!sl.isEmpty()) return sl.join(QStringLiteral(", "));
    }
    if (v.typeId() == QMetaType::QVariantList) {
        QStringList l; for (auto &x : v.toList()) l << unwrapDVariant(x).toString(); return l.join(QStringLiteral(", "));
    }
    QVariantList vl = v.toList();
    if (!vl.isEmpty()) {
        QStringList sl; for (auto &x : vl) sl << unwrapDVariant(x).toString(); return sl.join(QStringLiteral(", "));
    }
    return v.toString();
}
QString MprisController::artUrlFromMetadata(const QVariantMap &md) {
    QVariant v = unwrapDVariant(md.value(QStringLiteral("mpris:artUrl")));
    if (!v.isValid() || v.toString().isEmpty()) {
        auto v2 = md.value(QStringLiteral("mpris:artUrl"));
        v = unwrapDVariant(v2);
    }
    return v.toString();
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
    // fallback if length <= position (fork bug) -> keep length as is, no extra metadata fallback here because length already from metadata
    if (lenSec <= 0) lenSec = 0;
    setPolledLength(lenSec);
    // position with elapsed
    qint64 baseUs = info.positionUs;
    double baseSec = baseUs / 1e6;
    if (isPlaying) {
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
void MprisController::setActivePlayerDbusName(const QString &v) { if (m_activePlayerDbusName==v) return; m_activePlayerDbusName=v; emit activePlayerDbusNameChanged(); }

void MprisController::playPause() {
    if (m_activePlayerDbusName.isEmpty()) return;
    QDBusInterface iface(m_activePlayerDbusName, QStringLiteral("/org/mpris/MediaPlayer2"), QStringLiteral("org.mpris.MediaPlayer2.Player"), QDBusConnection::sessionBus());
    iface.call(QStringLiteral("PlayPause"));
}
void MprisController::next() {
    if (m_activePlayerDbusName.isEmpty()) return;
    QDBusInterface iface(m_activePlayerDbusName, QStringLiteral("/org/mpris/MediaPlayer2"), QStringLiteral("org.mpris.MediaPlayer2.Player"), QDBusConnection::sessionBus());
    iface.call(QStringLiteral("Next"));
}
void MprisController::prev() {
    if (m_activePlayerDbusName.isEmpty()) return;
    QDBusInterface iface(m_activePlayerDbusName, QStringLiteral("/org/mpris/MediaPlayer2"), QStringLiteral("org.mpris.MediaPlayer2.Player"), QDBusConnection::sessionBus());
    iface.call(QStringLiteral("Previous"));
}
void MprisController::seek(double positionSeconds) {
    if (m_activePlayerDbusName.isEmpty()) return;
    auto it = m_players.find(m_activePlayerDbusName);
    if (it == m_players.end() || !it->canSeek) return;
    qint64 us = qint64(positionSeconds * 1e6);
    // SetPosition needs TrackId
    QDBusInterface propIface(m_activePlayerDbusName, QStringLiteral("/org/mpris/MediaPlayer2"), QStringLiteral("org.freedesktop.DBus.Properties"), QDBusConnection::sessionBus());
    QDBusReply<QVariant> r = propIface.call(QStringLiteral("Get"), QStringLiteral("org.mpris.MediaPlayer2.Player"), QStringLiteral("Metadata"));
    QString trackId = QStringLiteral("/org/mpris/MediaPlayer2/TrackList/NoTrack");
    if (r.isValid()) {
        QVariantMap md;
        QVariant v = unwrapDVariant(r.value());
        md = qdbus_cast<QVariantMap>(v);
        if (md.isEmpty()) md = v.toMap();
        QVariant tid = unwrapDVariant(md.value(QStringLiteral("mpris:trackid")));
        if (tid.canConvert<QDBusObjectPath>()) trackId = qvariant_cast<QDBusObjectPath>(tid).path();
        else if (tid.userType() == qMetaTypeId<QDBusArgument>()) {
            QDBusObjectPath op = qdbus_cast<QDBusObjectPath>(qvariant_cast<QDBusArgument>(tid));
            trackId = op.path();
        } else if (tid.isValid()) trackId = tid.toString();
    }
    QDBusInterface iface(m_activePlayerDbusName, QStringLiteral("/org/mpris/MediaPlayer2"), QStringLiteral("org.mpris.MediaPlayer2.Player"), QDBusConnection::sessionBus());
    iface.call(QStringLiteral("SetPosition"), QVariant::fromValue(QDBusObjectPath(trackId)), us);
    // also try Seek offset as fallback
    m_positionBaseUs = us; m_positionBaseSec = positionSeconds; m_elapsed.restart();
    updatePolledValues();
}
void MprisController::refresh() { discoverPlayers(); for (auto &k : m_players.keys()) fetchPlayerState(k); updateActivePlayer(); }
