#pragma once

#include "AddOnBackend.h"
#include <QVariantList>
#include <QtQmlIntegration/qqmlintegration.h>

namespace matome {
class AddOnManager : public QObject
{
    Q_OBJECT
    QML_ANONYMOUS
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(bool canInstall READ canInstall NOTIFY changed)
    Q_PROPERTY(QVariantList spaces READ spaces NOTIFY changed)
    Q_PROPERTY(QString errorCode READ errorCode NOTIFY changed)
    Q_PROPERTY(QString notice READ notice NOTIFY changed)

public:
    explicit AddOnManager(AddOnBackend &backend, QObject *parent = nullptr);
    void setContext(const QString &orgId, bool canRead, bool canInstall);
    bool busy() const { return m_pending > 0 || m_saving; }
    bool canInstall() const { return m_canInstall; }
    QString errorCode() const { return m_errorCode; }
    QString notice() const { return m_notice; }
    QVariantList spaces() const { return m_spaces.toVariantList(); }
    QJsonArray products() const;
    QJsonObject product(const QString &key) const;
    QJsonObject entitlements() const { return m_entitlements; }
    AddOnBackend &backend() { return m_backend; }
    Q_INVOKABLE QVariantMap state(const QString &key, const QString &spaceId) const;
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void install(const QString &key, const QVariantList &spaceIds);
    Q_INVOKABLE void pause(const QString &key);
    Q_INVOKABLE void uninstallControlledDocs(const QString &reason);

signals:
    void changed();

private:
    bool live(int generation) const;
    bool entitled(const QString &key) const;
    bool catalogued(const QString &key) const;
    void mutate(const QByteArray &method, const QString &key, const QString &suffix,
                const QJsonObject &body, Client::Headers headers, const QString &notice);
    AddOnBackend &m_backend;
    QString m_orgId;
    bool m_canRead = false, m_canInstall = false, m_saving = false, m_loaded = false;
    int m_generation = 0, m_pending = 0;
    QJsonArray m_catalog, m_products, m_spaces;
    QJsonObject m_entitlements;
    QString m_errorCode, m_notice;
};
}
