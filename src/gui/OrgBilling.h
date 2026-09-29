#pragma once

#include "Client.h"
#include <QDateTime>
#include <QJsonArray>
#include <QTimer>
#include <QVariantList>
#include <QtQmlIntegration/qqmlintegration.h>

namespace matome {
class Session;

class OrgBilling : public QObject
{
    Q_OBJECT
    QML_ANONYMOUS
    Q_PROPERTY(bool available READ available NOTIFY changed)
    Q_PROPERTY(bool active READ active NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(bool canManage READ canManage NOTIFY changed)
    Q_PROPERTY(QString name READ name NOTIFY changed)
    Q_PROPERTY(QString plan READ plan NOTIFY changed)
    Q_PROPERTY(QVariantMap subscription READ subscription NOTIFY changed)
    Q_PROPERTY(QVariantList packages READ packages NOTIFY changed)
    Q_PROPERTY(QString packagesError READ packagesError NOTIFY changed)
    Q_PROPERTY(QVariantList products READ products NOTIFY changed)
    Q_PROPERTY(QVariantList usage READ usage NOTIFY changed)
    Q_PROPERTY(QString billingError READ billingError NOTIFY changed)
    Q_PROPERTY(QString usageError READ usageError NOTIFY changed)
    Q_PROPERTY(QString errorCode READ errorCode NOTIFY changed)
    Q_PROPERTY(QString notice READ notice NOTIFY changed)
    Q_PROPERTY(QString paymentUrl READ paymentUrl NOTIFY changed)

public:
    explicit OrgBilling(Session &session);
    bool available() const;
    bool active() const { return m_active; }
    bool busy() const;
    bool canManage() const;
    QString name() const;
    QString plan() const;
    QVariantMap subscription() const { return m_subscription.toVariantMap(); }
    QVariantList packages() const { return m_packages.toVariantList(); }
    QString packagesError() const { return m_packagesError; }
    QVariantList products() const;
    QVariantList usage() const;
    QString billingError() const { return m_billingError; }
    QString usageError() const { return m_usageError; }
    QString errorCode() const { return m_errorCode; }
    QString notice() const { return m_notice; }
    QString paymentUrl() const;

    void open();
    void close();
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void createPortal();
    Q_INVOKABLE void setQuantity(const QString &sku, int quantity);
    Q_INVOKABLE void selectPackage(const QString &key, int version);

signals:
    void changed();

private:
    bool live(int generation) const;
    bool canSave() const;
    void load();
    Client::Done saved(const QString &notice);
    static QString returnUrl();

    Session &m_session;
    QString m_orgId;
    bool m_active = false;
    bool m_saving = false;
    int m_generation = 0;
    int m_pending = 0;
    QJsonObject m_subscription;
    QJsonObject m_usage;
    QJsonArray m_packages;
    QString m_billingError, m_usageError, m_errorCode, m_notice, m_paymentUrl;
    QString m_packagesError;
    QDateTime m_checkoutExpiresAt;
    QTimer m_paymentExpiry;
};
}
