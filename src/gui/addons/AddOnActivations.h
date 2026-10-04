#pragma once

#include "addons/AddOnManager.h"

#include <QHash>
#include <QJsonArray>
#include <QVariantList>
#include <QtQmlIntegration/qqmlintegration.h>

namespace matome {
class Session;

/// Where the installed add-ons of the current organization are active: each
/// space's add-ons as Core lists them, read from every space of the
/// organization, and turning one on or off in one space with its space
/// settings. Controlled documents' activation is the space's review switch.
/// Reading and changing a space's add-ons needs `add_on.space_activate` there.
class AddOnActivations : public QObject
{
    Q_OBJECT
    QML_ANONYMOUS
    Q_PROPERTY(bool active READ active NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(QVariantList rows READ rows NOTIFY listsChanged)
    Q_PROPERTY(QString readError READ readError NOTIFY changed)
    Q_PROPERTY(QString errorCode READ errorCode NOTIFY changed)
    Q_PROPERTY(QString notice READ notice NOTIFY changed)

public:
    AddOnActivations(Session &session, AddOnManager &addOns);
    bool active() const { return !m_orgId.isEmpty(); }
    bool busy() const { return m_reading > 0 || m_writing > 0; }
    /// One row per space and space-scoped add-on installed there, as
    /// `GET …/spaces/:id/add-ons` lists it (`product_key`, `status`,
    /// `active`, `installation_status`, `settings`, `effective_settings`,
    /// `revision`), with its `space_id` and `space_name`, spaces in the
    /// organization's order.
    QVariantList rows() const;
    /// The code the first space read failed with.
    QString readError() const { return m_readError; }
    QString errorCode() const { return m_errorCode; }
    QString notice() const { return m_notice; }

    /// Reads the add-ons of every space of the current organization, and
    /// again whenever its spaces or installations change.
    Q_INVOKABLE void open();
    Q_INVOKABLE void close();
    Q_INVOKABLE void refresh();
    /// Turns `key` on in `spaceId`, with `settings` merged over the space's
    /// overrides; a null value drops an override.
    Q_INVOKABLE void activate(const QString &spaceId, const QString &key, const QVariantMap &settings = {});
    /// Turns `key` off in `spaceId`, keeping its settings.
    Q_INVOKABLE void deactivate(const QString &spaceId, const QString &key);
    /// Reads the activation of `product` in `spaceId` of `orgId`: `done`
    /// gets it, empty when the add-on is not installed, or the code the read
    /// failed with (`forbidden` without `add_on.space_activate`).
    static void read(AddOnBackend &backend, const QString &orgId, const QString &spaceId, const QString &product,
                     AddOnBackend::Live live, std::function<void(const QJsonObject &activation, const QString &error)> done);

signals:
    void changed();
    /// The rows differ from before.
    void listsChanged();

private:
    bool live(int generation) const { return active() && generation == m_generation; }
    QJsonObject row(const QString &spaceId, const QString &key) const;
    /// The spaces and installation states the rows were read under.
    QString stamp() const;
    void change(const QByteArray &method, const QString &spaceId, const QString &key, const QJsonObject &body,
                const QString &notice);

    Session &m_session;
    AddOnManager &m_addOns;
    AddOnBackend &m_backend;
    QString m_orgId, m_stamp, m_readError, m_errorCode, m_notice;
    int m_generation = 0, m_reading = 0, m_writing = 0;
    QHash<QString, QJsonArray> m_spaceRows;
    /// The lists last notified, as compact JSON.
    QByteArray m_listed;
};
}
