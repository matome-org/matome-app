#include "OrgBilling.h"
#include "JsonList.h"
#include "Session.h"

#include <chrono>

#ifdef Q_OS_WASM
#include <emscripten/val.h>
#endif

namespace matome {

OrgBilling::OrgBilling(Session &session)
    : QObject(&session), m_session(session), m_paymentExpiry(this)
{
    m_paymentExpiry.setSingleShot(true);
    m_paymentExpiry.setTimerType(Qt::PreciseTimer);
    connect(&m_paymentExpiry, &QTimer::timeout, this, [this] {
        m_paymentUrl.clear();
        m_notice.clear();
        m_errorCode = QStringLiteral("checkout_expired");
        emit changed();
    });
    connect(&session, &Session::changed, this, [this] {
        if (m_active && (!available() || m_orgId != m_session.currentOrgId()))
            close();
        else
            emit changed();
    });
}

bool OrgBilling::available() const
{
    return m_session.signedIn()
            && m_session.organizations()->canReadBilling(m_session.currentOrgId());
}

bool OrgBilling::canManage() const
{
    return available() && m_session.organizations()->canManageBilling(m_session.currentOrgId());
}

bool OrgBilling::canInstall() const
{
    return available() && m_session.organizations()->canAdminister(m_session.currentOrgId());
}

QString OrgBilling::name() const
{
    return m_session.organizations()->nameOf(m_session.currentOrgId());
}

QString OrgBilling::plan() const
{
    return m_entitlements.value(QStringLiteral("plan")).toObject().value(QStringLiteral("key")).toString();
}

QString OrgBilling::paymentUrl() const
{
    return m_checkoutExpiresAt.isValid() && m_checkoutExpiresAt <= QDateTime::currentDateTimeUtc()
            ? QString() : m_paymentUrl;
}

void OrgBilling::open()
{
    if (m_active || !available()) return;
    m_active = true;
    m_orgId = m_session.currentOrgId();
    load();
}

void OrgBilling::close()
{
    m_paymentExpiry.stop();
    m_checkoutExpiresAt = {};
    ++m_generation;
    m_active = false;
    m_saving = false;
    m_pending = 0;
    m_orgId.clear();
    m_subscription = {};
    m_entitlements = {};
    m_usage = {};
    m_catalog = {};
    m_packages = {};
    m_products = {};
    m_spaces = {};
    m_billingError.clear(); m_productsError.clear(); m_usageError.clear();
    m_errorCode.clear(); m_notice.clear(); m_paymentUrl.clear();
    m_packagesError.clear();
    emit changed();
}

bool OrgBilling::live(int generation) const
{
    return generation == m_generation && m_active && available()
            && m_orgId == m_session.currentOrgId();
}

bool OrgBilling::canSave() const { return live(m_generation) && !busy(); }

void OrgBilling::refresh()
{
    if (!canSave()) return;
    m_paymentExpiry.stop();
    m_checkoutExpiresAt = {};
    m_errorCode.clear(); m_notice.clear(); m_paymentUrl.clear();
    load();
}

void OrgBilling::load()
{
    const int generation = ++m_generation;
    m_pending = canInstall() ? 7 : 6;
    m_billingError.clear(); m_productsError.clear(); m_usageError.clear();
    m_packagesError.clear();
    emit changed();
    const auto get = [this, generation](const QString &path, const QString &key,
                                        QJsonObject &data, QString &error) {
        m_session.authedGet(path, [this, generation, key, &data, &error](const Client::Reply &reply) {
            if (!live(generation)) return;
            data = reply.ok ? reply.json.value(key).toObject() : QJsonObject();
            if (!reply.ok) error = failCode(reply);
            --m_pending;
            emit changed();
        });
    };
    get(orgPath(m_orgId, QStringLiteral("billing/subscription")), QStringLiteral("subscription"), m_subscription, m_billingError);
    get(orgPath(m_orgId, QStringLiteral("entitlements")), QStringLiteral("entitlements"), m_entitlements, m_usageError);
    get(orgPath(m_orgId, QStringLiteral("usage")), QStringLiteral("usage"), m_usage, m_usageError);
    const auto list = [this, generation](const QString &path, const QString &key, QJsonArray &data, QString &error) {
        m_session.authedList(path, key, [this, generation] { return live(generation); },
                [this, generation, &data, &error](const Client::Reply &reply, const QJsonArray &rows) {
            if (!live(generation)) return;
            data = reply.ok ? rows : QJsonArray();
            if (!reply.ok) error = failCode(reply);
            --m_pending;
            emit changed();
        });
    };
    list(orgPath(m_orgId, QStringLiteral("billing/packages")), QStringLiteral("packages"), m_packages, m_packagesError);
    list(QStringLiteral("/api/v1/add-ons"), QStringLiteral("products"), m_catalog, m_productsError);
    list(orgPath(m_orgId, QStringLiteral("add-ons")), QStringLiteral("products"), m_products, m_productsError);
    if (canInstall())
        list(orgPath(m_orgId, QStringLiteral("spaces")), QStringLiteral("spaces"), m_spaces, m_productsError);
    else
        m_spaces = {};
}

QJsonObject OrgBilling::productRow(const QString &key) const
{
    for (const QJsonValue &value : m_products)
        if (value.toObject().value(QStringLiteral("key")).toString() == key) return value.toObject();
    return {};
}

QVariantList OrgBilling::products() const
{
    QVariantList result;
    QJsonArray catalog = m_catalog;
    for (const QJsonValue &value : m_products) {
        const QJsonObject owned = value.toObject();
        bool listed = false;
        for (const QJsonValue &entry : m_catalog)
            listed |= entry.toObject().value(QStringLiteral("key")) == owned.value(QStringLiteral("key"));
        if (!listed) {
            QJsonObject product = owned;
            product.insert(QStringLiteral("name"), owned.value(QStringLiteral("key")));
            product.insert(QStringLiteral("skus"), QJsonArray());
            catalog.append(product);
        }
    }
    for (const QJsonValue &value : catalog) {
        QJsonObject product = value.toObject();
        const QJsonObject owned = productRow(product.value(QStringLiteral("key")).toString());
        for (auto it = owned.begin(); it != owned.end(); ++it) product.insert(it.key(), it.value());
        QJsonArray skus;
        for (const QJsonValue &entry : product.value(QStringLiteral("skus")).toArray()) {
            QJsonObject sku = entry.toObject();
            int purchased = 0, assigned = 0;
            const QString key = sku.value(QStringLiteral("key")).toString();
            const int version = sku.value(QStringLiteral("version")).toInt();
            bool latest = true;
            for (const QJsonValue &candidate : product.value(QStringLiteral("skus")).toArray()) {
                const QJsonObject row = candidate.toObject();
                if (row.value(QStringLiteral("key")).toString() == key
                        && row.value(QStringLiteral("version")).toInt() > version) latest = false;
            }
            if (!latest) continue;
            for (const QJsonValue &item : m_subscription.value(QStringLiteral("add_ons")).toArray()) {
                const QJsonObject row = item.toObject();
                if (row.value(QStringLiteral("key")).toString() == key)
                    purchased += row.value(QStringLiteral("quantity")).toInt();
            }
            for (const QJsonValue &item : owned.value(QStringLiteral("assignments")).toArray()) {
                const QJsonObject row = item.toObject();
                if (row.value(QStringLiteral("key")).toString() == key)
                    assigned += row.value(QStringLiteral("quantity")).toInt();
            }
            sku.insert(QStringLiteral("purchased"), purchased);
            sku.insert(QStringLiteral("assigned"), assigned);
            skus.append(sku);
        }
        product.insert(QStringLiteral("skus"), skus);
        result.append(product.toVariantMap());
    }
    return result;
}

QVariantList OrgBilling::usage() const
{
    QVariantList result;
    const QJsonObject dimensions = m_usage.value(QStringLiteral("dimensions")).toObject();
    const QJsonObject limits = m_usage.value(QStringLiteral("limits")).toObject();
    for (const char *key : {"storage_bytes", "members", "guests", "spaces"}) {
        const QString dimension = QString::fromLatin1(key);
        if (!dimensions.contains(dimension)) continue;
        const QJsonObject amount = dimensions.value(dimension).toObject();
        result.append(QVariantMap{{QStringLiteral("dimension"), dimension},
                {QStringLiteral("used"), amount.value(QStringLiteral("confirmed")).toVariant()},
                {QStringLiteral("reserved"), amount.value(QStringLiteral("reserved")).toVariant()},
                {QStringLiteral("limit"), limits.value(dimension).toVariant()}});
    }
    return result;
}

Client::Done OrgBilling::saved(const QString &notice)
{
    m_paymentExpiry.stop();
    m_checkoutExpiresAt = {};
    m_saving = true;
    m_errorCode.clear(); m_notice.clear(); m_paymentUrl.clear();
    const int generation = m_generation;
    emit changed();
    return [this, generation, notice](const Client::Reply &reply) {
        if (!live(generation)) return;
        m_saving = false;
        m_errorCode = reply.ok ? QString() : failCode(reply);
        if (reply.ok) {
            m_notice = notice;
            if (notice == QLatin1String("portal") || notice == QLatin1String("checkout")) {
                const QUrl url(reply.json.value(QStringLiteral("url")).toString());
                if (url.isValid() && url.scheme() == QLatin1String("https") && !url.host().isEmpty())
                    m_paymentUrl = url.toString();
                else
                    m_errorCode = QStringLiteral("invalid_request");
                if (notice == QLatin1String("checkout") && !m_paymentUrl.isEmpty()) {
                    m_checkoutExpiresAt = QDateTime::fromString(
                            reply.json.value(QStringLiteral("expires_at")).toString(), Qt::ISODate);
                    const qint64 remaining = QDateTime::currentDateTimeUtc().msecsTo(m_checkoutExpiresAt);
                    if (!m_checkoutExpiresAt.isValid() || remaining <= 0) {
                        m_paymentUrl.clear();
                        m_errorCode = m_checkoutExpiresAt.isValid() ? QStringLiteral("checkout_expired")
                                                                   : QStringLiteral("invalid_request");
                    } else {
                        m_paymentExpiry.start(std::chrono::milliseconds(remaining));
                    }
                }
                emit changed();
            } else {
                load();
            }
        } else {
            emit changed();
        }
    };
}

QString OrgBilling::returnUrl()
{
#ifdef Q_OS_WASM
    return QString::fromStdString(emscripten::val::global("location")["origin"].as<std::string>()) + QLatin1Char('/');
#else
    return QStringLiteral("https://app.matome.io/");
#endif
}

void OrgBilling::createPortal()
{
    if (!canSave() || !canManage() || !m_billingError.isEmpty()) return;
    m_session.authedPost(orgPath(m_orgId, QStringLiteral("billing/portal-sessions")),
            {{QStringLiteral("return_url"), returnUrl()}}, idempotencyHeader(), saved(QStringLiteral("portal")));
}

void OrgBilling::selectPackage(const QString &key, int version)
{
    if (!canSave() || !canManage() || !m_billingError.isEmpty() || !m_packagesError.isEmpty()
            || m_subscription.value(QStringLiteral("pending_update")).toBool()) return;
    bool found = false;
    for (const QJsonValue &value : m_packages) {
        const QJsonObject row = value.toObject();
        found |= row.value(QStringLiteral("key")).toString() == key
                && row.value(QStringLiteral("version")).toInt() == version;
    }
    if (!found) return;
    QJsonObject body{{QStringLiteral("package"), QJsonObject{{QStringLiteral("key"), key}, {QStringLiteral("version"), version}}}};
    const QString status = m_subscription.value(QStringLiteral("status")).toString();
    const bool liveSubscription = !m_subscription.isEmpty()
            && status != QLatin1String("canceled") && status != QLatin1String("incomplete_expired");
    if (liveSubscription) {
        m_session.authedPut(orgPath(m_orgId, QStringLiteral("billing/subscription")), body,
                idempotencyHeader(), saved(QStringLiteral("billing_requested")));
    } else {
        body.insert(QStringLiteral("success_url"), returnUrl());
        body.insert(QStringLiteral("cancel_url"), returnUrl());
        m_session.authedPost(orgPath(m_orgId, QStringLiteral("billing/checkout-sessions")), body,
                idempotencyHeader(), saved(QStringLiteral("checkout")));
    }
}

void OrgBilling::setQuantity(const QString &key, int quantity)
{
    if (!canSave() || !canManage() || !m_billingError.isEmpty() || !m_productsError.isEmpty()
            || quantity < 0 || m_subscription.value(QStringLiteral("plan")).toObject().isEmpty()
            || m_subscription.value(QStringLiteral("status")).toString() == QLatin1String("canceled")
            || m_subscription.value(QStringLiteral("status")).toString() == QLatin1String("incomplete_expired")
            || m_subscription.value(QStringLiteral("pending_update")).toBool()) return;
    QJsonObject selected;
    for (const QJsonValue &value : m_catalog)
        for (const QJsonValue &sku : value.toObject().value(QStringLiteral("skus")).toArray())
            if (sku.toObject().value(QStringLiteral("key")).toString() == key
                    && (selected.isEmpty() || sku.toObject().value(QStringLiteral("version")).toInt()
                        > selected.value(QStringLiteral("version")).toInt())) selected = sku.toObject();
    if (selected.isEmpty() || (quantity > 1 && !selected.value(QStringLiteral("stackable")).toBool())) return;
    QJsonArray desired;
    for (const QJsonValue &value : m_subscription.value(QStringLiteral("add_ons")).toArray()) {
        const QJsonObject item = value.toObject();
        if (item.value(QStringLiteral("key")).toString() != key)
            desired.append(QJsonObject{{QStringLiteral("sku"), item.value(QStringLiteral("key"))},
                    {QStringLiteral("quantity"), item.value(QStringLiteral("quantity"))}});
    }
    if (quantity > 0) desired.append(QJsonObject{{QStringLiteral("sku"), key}, {QStringLiteral("quantity"), quantity}});
    m_session.authedPut(orgPath(m_orgId, QStringLiteral("billing/subscription")),
            {{QStringLiteral("plan"), m_subscription.value(QStringLiteral("plan")).toObject().value(QStringLiteral("key"))},
             {QStringLiteral("add_ons"), desired}}, idempotencyHeader(), saved(QStringLiteral("billing_requested")));
}

void OrgBilling::install(const QString &key, const QVariantList &spaceIds)
{
    if (!canSave() || !canInstall() || !m_productsError.isEmpty()) return;
    const QJsonObject product = productRow(key);
    if (product.value(QStringLiteral("assignments")).toArray().isEmpty()) return;
    for (const QVariant &id : spaceIds) {
        bool found = false;
        for (const QJsonValue &space : m_spaces)
            found |= jsonId(space.toObject().value(QStringLiteral("id"))) == id.toString();
        if (!found) {
            m_errorCode = QStringLiteral("invalid_space");
            emit changed();
            return;
        }
    }
    const QJsonObject installation = product.value(QStringLiteral("installation")).toObject();
    m_session.authedPut(orgPath(m_orgId, QStringLiteral("add-ons/%1/installation").arg(key)),
            {{QStringLiteral("settings"), installation.value(QStringLiteral("settings")).toObject()},
             {QStringLiteral("space_ids"), QJsonArray::fromVariantList(spaceIds)}},
            idempotencyHeader(), saved(QStringLiteral("installation_saved")));
}

void OrgBilling::pause(const QString &key)
{
    if (!canSave() || !canInstall() || !m_productsError.isEmpty()) return;
    if (productRow(key).value(QStringLiteral("installation")).toObject().value(QStringLiteral("status")).toString() != QLatin1String("active")) return;
    m_session.authedPost(orgPath(m_orgId, QStringLiteral("add-ons/%1/installation/pause").arg(key)),
            {}, idempotencyHeader(), saved(QStringLiteral("installation_paused")));
}
}
