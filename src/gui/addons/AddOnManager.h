#pragma once

#include "AddOnBackend.h"
#include "JsonList.h"
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
    Q_PROPERTY(QVariantList members READ members NOTIFY changed)
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
    /// Active memberships, as picker choices, that may answer for an installation.
    QVariantList members() const;
    QJsonArray products() const;
    /// The organization's row of `key`, its `installation` null while there
    /// is none or it is uninstalled.
    QJsonObject product(const QString &key) const;
    QJsonObject entitlements() const { return m_entitlements; }
    AddOnBackend &backend() { return m_backend; }
    /// `{known, entitled, status, available}` of `key` in the organization;
    /// `status` is empty while it is not installed. Where it is available,
    /// each space still turns it on for itself.
    Q_INVOKABLE QVariantMap state(const QString &key) const;
    Q_INVOKABLE void refresh();
    /// Installs `key` in the organization, which makes it available in every
    /// space and active in none, with `settings` over the installation's
    /// current settings. Core makes the installer its responsible member.
    Q_INVOKABLE void install(const QString &key, const QVariantMap &settings = {});
    /// Resumes the paused `key` with the settings it was saved with.
    Q_INVOKABLE void resume(const QString &key);
    /// Changes the organization's settings of the installed `key`; the
    /// settings it omits keep their values.
    Q_INVOKABLE void saveSettings(const QString &key, const QVariantMap &settings);
    /// Makes `membershipId` the membership the installed `key` acts for.
    Q_INVOKABLE void assign(const QString &key, const QString &membershipId);
    Q_INVOKABLE void pause(const QString &key);
    /// Uninstalls `key`, which then reads as not installed until it is
    /// installed again; Core keeps its activations, space settings, and
    /// grants for a reinstall. Document control needs a `reason`: Core
    /// cancels its open reviews and removes it from every document.
    Q_INVOKABLE void uninstall(const QString &key, const QString &reason = {});

signals:
    void changed();

private:
    bool live(int generation) const;
    bool entitled(const QString &key) const;
    bool catalogued(const QString &key) const;
    void loaded(const Client::Reply &reply);
    void mutate(const QByteArray &method, const QString &key, const QString &suffix,
                const QJsonObject &body, Client::Headers headers, const QString &notice);
    AddOnBackend &m_backend;
    QString m_orgId;
    bool m_canRead = false, m_canInstall = false, m_saving = false, m_loaded = false, m_again = false;
    int m_generation = 0, m_pending = 0;
    QJsonArray m_catalog, m_products, m_spaces, m_members;
    QJsonObject m_entitlements;
    QString m_errorCode, m_notice;
};
}
