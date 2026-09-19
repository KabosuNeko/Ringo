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

    Q_INVOKABLE void play(const QString &soundNameOrPath);
    Q_INVOKABLE void playAlarm();
    Q_INVOKABLE void playComplete();
    Q_INVOKABLE void playBell();
    Q_INVOKABLE void playCamera();
    Q_INVOKABLE void playWarning();

private:
    QString resolveSoundPath(const QString &sound) const;
    QString m_playerBinary;
};
