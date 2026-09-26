#pragma once
#include <QObject>
#include <QString>
#include <QtQml/qqml.h>

class SoundController final : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit SoundController(QObject *parent = nullptr);

    void play(const QString &soundNameOrPath);
    Q_INVOKABLE void playAlarm();
    Q_INVOKABLE void playComplete();

private:
    QString resolveSoundPath(const QString &sound) const;
    QString m_playerBinary;
};
