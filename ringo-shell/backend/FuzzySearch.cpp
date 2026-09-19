#include "FuzzySearch.h"
#include <algorithm>

FuzzySearch::FuzzySearch(QObject *parent)
    : QObject(parent)
{
}

int FuzzySearch::score(const QString &pattern, const QString &target) const
{
    if (pattern.isEmpty()) return 100;
    if (target.isEmpty()) return 0;

    const QString pLower = pattern.toLower();
    const QString tLower = target.toLower();

    if (tLower == pLower) return 1000;
    if (tLower.startsWith(pLower)) return 500 + (100 - std::min<int>(static_cast<int>(target.length()), 100));

    int pIdx = 0;
    int tIdx = 0;
    int matchScore = 0;
    int consecutive = 0;
    bool prevMatched = false;

    const int pLen = pLower.length();
    const int tLen = tLower.length();

    while (pIdx < pLen && tIdx < tLen) {
        const QChar pChar = pLower.at(pIdx);
        const QChar tChar = tLower.at(tIdx);

        if (pChar == tChar) {
            matchScore += 20;

            if (tIdx == 0) {
                matchScore += 60; // Start of target bonus
            } else {
                const QChar prevChar = target.at(tIdx - 1);
                // Word boundary bonus
                if (prevChar == QLatin1Char(' ') || prevChar == QLatin1Char('-') ||
                    prevChar == QLatin1Char('_') || prevChar == QLatin1Char('.') ||
                    prevChar == QLatin1Char('/')) {
                    matchScore += 45;
                } else if (prevChar.isLower() && target.at(tIdx).isUpper()) {
                    matchScore += 40; // camelCase bonus
                }
            }

            if (prevMatched) {
                consecutive++;
                matchScore += (consecutive * 15);
            } else {
                consecutive = 0;
            }

            prevMatched = true;
            pIdx++;
        } else {
            prevMatched = false;
            consecutive = 0;
        }
        tIdx++;
    }

    if (pIdx < pLen) {
        return 0; // Not all pattern characters were found in sequence
    }

    // Small penalty for total string length to prefer tighter matches
    matchScore -= std::min<int>(static_cast<int>(tLen - pLen), 50);

    return std::max(matchScore, 1);
}

bool FuzzySearch::matchesCategory(const QVariantMap &appMap, const QString &category)
{
    if (category == QStringLiteral("All") || category.isEmpty()) {
        return true;
    }

    const QString name = appMap.value(QStringLiteral("name")).toString().toLower();
    const QString comment = appMap.value(QStringLiteral("comment")).toString().toLower();
    
    QString categoriesStr;
    const QVariant entryVar = appMap.value(QStringLiteral("entry"));
    if (entryVar.canConvert<QVariantMap>()) {
        const QVariantMap entryMap = entryVar.toMap();
        categoriesStr = entryMap.value(QStringLiteral("categories")).toStringList().join(QLatin1Char(' ')).toLower();
    } else {
        categoriesStr = appMap.value(QStringLiteral("categories")).toString().toLower();
    }

    const QString combined = name + QLatin1Char(' ') + comment + QLatin1Char(' ') + categoriesStr;

    if (category == QStringLiteral("Dev")) {
        return combined.contains(QStringLiteral("development")) ||
               combined.contains(QStringLiteral("programming")) ||
               combined.contains(QStringLiteral("code")) ||
               combined.contains(QStringLiteral("git")) ||
               combined.contains(QStringLiteral("ide")) ||
               combined.contains(QStringLiteral("editor"));
    }
    if (category == QStringLiteral("Internet")) {
        return combined.contains(QStringLiteral("network")) ||
               combined.contains(QStringLiteral("webbrowser")) ||
               combined.contains(QStringLiteral("browser")) ||
               combined.contains(QStringLiteral("chat")) ||
               combined.contains(QStringLiteral("discord")) ||
               combined.contains(QStringLiteral("telegram")) ||
               combined.contains(QStringLiteral("mail"));
    }
    if (category == QStringLiteral("Media")) {
        return combined.contains(QStringLiteral("audiovideo")) ||
               combined.contains(QStringLiteral("audio")) ||
               combined.contains(QStringLiteral("video")) ||
               combined.contains(QStringLiteral("player")) ||
               combined.contains(QStringLiteral("graphics")) ||
               combined.contains(QStringLiteral("image")) ||
               combined.contains(QStringLiteral("music"));
    }
    if (category == QStringLiteral("System")) {
        return combined.contains(QStringLiteral("system")) ||
               combined.contains(QStringLiteral("utility")) ||
               combined.contains(QStringLiteral("settings")) ||
               combined.contains(QStringLiteral("terminal")) ||
               combined.contains(QStringLiteral("manager"));
    }

    return true;
}

QVariantList FuzzySearch::filterAndSort(const QVariantList &apps,
                                        const QString &query,
                                        const QString &category) const
{
    const QString qTrimmed = query.trimmed();

    struct ScoredApp {
        QVariant data;
        QString name;
        int score = 0;
    };

    QList<ScoredApp> candidates;
    candidates.reserve(apps.size());

    for (const auto &item : apps) {
        const QVariantMap appMap = item.toMap();
        if (!matchesCategory(appMap, category)) {
            continue;
        }

        const QString name = appMap.value(QStringLiteral("name")).toString();
        const QString comment = appMap.value(QStringLiteral("comment")).toString();

        if (qTrimmed.isEmpty()) {
            candidates.append({item, name, 0});
        } else {
            int nameScore = score(qTrimmed, name);
            int commentScore = score(qTrimmed, comment) / 2;
            int finalScore = std::max(nameScore, commentScore);

            if (finalScore > 0) {
                candidates.append({item, name, finalScore});
            }
        }
    }

    if (qTrimmed.isEmpty()) {
        std::sort(candidates.begin(), candidates.end(), [](const ScoredApp &a, const ScoredApp &b) {
            return QString::localeAwareCompare(a.name, b.name) < 0;
        });
    } else {
        std::sort(candidates.begin(), candidates.end(), [](const ScoredApp &a, const ScoredApp &b) {
            if (a.score != b.score) return a.score > b.score;
            return QString::localeAwareCompare(a.name, b.name) < 0;
        });
    }

    QVariantList result;
    result.reserve(candidates.size());
    for (const auto &c : candidates) {
        result.append(c.data);
    }
    return result;
}
