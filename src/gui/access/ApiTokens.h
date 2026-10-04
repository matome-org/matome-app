#pragma once

#include "addons/AddOnBackend.h"

#include <QJsonArray>
#include <QVariantList>
#include <QtQmlIntegration/qqmlintegration.h>

namespace matome {
class Session;

/// The signed-in user's personal API tokens. A token holds scopes, each one
/// action in one organization: organization-wide, in one space, or in every
/// space the user can reach when the token is used. Core shows a new
/// token's secret once.
class ApiTokens : public QObject
{
    Q_OBJECT
    QML_ANONYMOUS
    Q_PROPERTY(bool active READ active NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(QVariantList tokens READ tokens NOTIFY changed)
    Q_PROPERTY(QVariantList organizations READ organizations NOTIFY changed)
    Q_PROPERTY(QVariantList spaces READ spaces NOTIFY changed)
    Q_PROPERTY(QVariantList actions READ actions NOTIFY changed)
    Q_PROPERTY(bool needsPassword READ needsPassword NOTIFY changed)
    Q_PROPERTY(QString secret READ secret NOTIFY changed)
    Q_PROPERTY(QString errorCode READ errorCode NOTIFY changed)
    Q_PROPERTY(QString notice READ notice NOTIFY changed)

public:
    ApiTokens(Session &session, AddOnBackend &backend);
    bool active() const { return m_active; }
    bool busy() const { return m_pending > 0 || m_spacesLoading || m_catalogLoading; }
    /// `{id, name, prefix, expiresAt, lastUsedAt, scopes}`, each scope
    /// `{organizationId, organizationName, action, spaceId, allSpaces}`.
    QVariantList tokens() const;
    /// The user's organizations as picker choices.
    QVariantList organizations() const;
    /// The spaces of the organization chosen with `choose`, as picker choices.
    QVariantList spaces() const;
    /// `{key, area}` for each action a token may hold at the chosen target.
    QVariantList actions() const;
    bool needsPassword() const;
    QString secret() const { return m_secret; }
    QString errorCode() const { return m_errorCode; }
    QString notice() const { return m_notice; }

    Q_INVOKABLE void open();
    Q_INVOKABLE void close();
    Q_INVOKABLE void refresh();
    /// Lists what a token may hold in `orgId` at `target`: "" for the
    /// organization, "*" for every space, or a space id.
    Q_INVOKABLE void choose(const QString &orgId, const QString &target);
    /// Creates a token named `name` lasting `days` with `scopes`, each
    /// `{organization_id, action}` plus `space_id` or `all_spaces`;
    /// `password` signs in again when the session is too old.
    Q_INVOKABLE void create(const QString &name, int days, const QVariantList &scopes, const QString &password);
    Q_INVOKABLE void revoke(const QString &id);
    /// Drops the new token's secret once the user has kept it.
    Q_INVOKABLE void forgetSecret();

signals:
    void changed();

private:
    bool live(int generation) const { return m_active && generation == m_generation; }
    void post(const QString &name, int days, const QJsonArray &scopes);
    void finish(const Client::Reply &reply);

    Session &m_session;
    AddOnBackend &m_backend;
    bool m_active = false, m_stale = false, m_spacesLoading = false, m_catalogLoading = false;
    int m_generation = 0, m_choice = 0, m_pending = 0;
    QJsonArray m_tokens, m_spaces, m_catalog;
    QString m_orgId, m_target, m_secret, m_errorCode, m_notice;
};
}
