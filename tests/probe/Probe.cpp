// Loaded into the real matome-studio by QT_QPA_GENERIC_PLUGINS before main()
// builds its engine. It waits for the window, reads what main.cpp wired
// (bundled fonts, the translator for the saved language, the window icon,
// the restored settings), signs in with MATOME_PROBE_PASSWORD by pressing
// Return in the password field, waits for the explorer to list, prints one
// "probe {json}" line, and quits. Every wait is a condition polled for up to
// 30 s; on timeout it prints what it saw and exits 1.

#include "Wiring.h"

#include <QAbstractItemModel>
#include <QColor>
#include <QElapsedTimer>
#include <QGenericPlugin>
#include <QJsonDocument>
#include <QKeyEvent>
#include <QTextStream>
#include <QTimer>

namespace {

QQuickItem *findItem(QQuickItem *root, const QString &name)
{
    for (QQuickItem *item : matome::probe::descendants(root)) {
        if (item->objectName() == name && item->isVisible())
            return item;
    }
    return nullptr;
}

QJsonArray names(QAbstractItemModel *model, const QByteArray &role)
{
    QJsonArray out;
    if (!model)
        return out;
    const int key = model->roleNames().key(role, -1);
    for (int row = 0; row < model->rowCount(); ++row)
        out.append(model->index(row, 0).data(key).toString());
    return out;
}

class Probe : public QObject
{
public:
    Probe()
    {
        m_clock.start();
        connect(&m_tick, &QTimer::timeout, this, [this] { step(); });
        m_tick.start(20);
    }

private:
    // The studio once it shows the sign-in screen.
    QQuickWindow *window() const
    {
        QQuickWindow *quick = matome::probe::exposedWindow();
        return quick && findItem(quick->contentItem(), QStringLiteral("authScreen")) ? quick
                                                                                    : nullptr;
    }

    QObject *singleton(const char *name) const
    {
        return matome::probe::singleton(m_window, QString::fromLatin1(name));
    }

    void step()
    {
        if (m_clock.elapsed() > TimeoutMs) {
            m_report.insert(QStringLiteral("timeout"), m_stage);
            finish(1);
            return;
        }
        if (m_stage == QLatin1String("window")) {
            m_window = window();
            if (!m_window)
                return;
            readWiring();
            signIn();
            m_stage = QStringLiteral("explorer");
            return;
        }
        QObject *session = singleton("Session");
        if (!session->property("signedIn").toBool() || session->property("loading").toBool()
            || !findItem(m_window->contentItem(), QStringLiteral("entryRow0")))
            return;
        m_report.insert(QStringLiteral("signedIn"), true);
        m_report.insert(QStringLiteral("childKind"), session->property("childKind").toString());
        m_report.insert(QStringLiteral("currentOrgId"), session->property("currentOrgId").toString());
        m_report.insert(QStringLiteral("organizations"),
                        names(session->property("organizations").value<QAbstractItemModel *>(),
                              "name"));
        m_report.insert(QStringLiteral("entries"),
                        names(session->property("entries").value<QAbstractItemModel *>(), "name"));
        finish(0);
    }

    void readWiring()
    {
        m_report = matome::probe::wiring();
        QObject *theme = singleton("Theme");
        QObject *session = singleton("Session");
        m_report.insert(QStringLiteral("mode"), theme->property("mode").toString());
        m_report.insert(QStringLiteral("dark"), theme->property("dark").toBool());
        m_report.insert(QStringLiteral("language"), theme->property("language").toString());
        m_report.insert(QStringLiteral("email"), session->property("email").toString());
        m_report.insert(QStringLiteral("apiBaseUrl"), session->property("apiBaseUrl").toString());
        QQuickItem *root = m_window->contentItem();
        m_report.insert(QStringLiteral("emailField"),
                        findItem(root, QStringLiteral("emailField"))->property("text").toString());
        m_report.insert(QStringLiteral("submitText"),
                        findItem(root, QStringLiteral("submitButton"))->property("text").toString());
        m_report.insert(QStringLiteral("windowColor"), m_window->color().name());
        m_report.insert(QStringLiteral("background"), theme->property("background").value<QColor>().name());
    }

    void signIn()
    {
        QQuickItem *password = findItem(m_window->contentItem(), QStringLiteral("passwordField"));
        password->setProperty("text", qEnvironmentVariable("MATOME_PROBE_PASSWORD"));
        password->forceActiveFocus();
        QKeyEvent press(QEvent::KeyPress, Qt::Key_Return, Qt::NoModifier);
        QCoreApplication::sendEvent(m_window, &press);
        QKeyEvent release(QEvent::KeyRelease, Qt::Key_Return, Qt::NoModifier);
        QCoreApplication::sendEvent(m_window, &release);
    }

    void finish(int code)
    {
        m_tick.stop();
        QTextStream(stdout) << "probe "
                            << QJsonDocument(m_report).toJson(QJsonDocument::Compact) << Qt::endl;
        QCoreApplication::exit(code);
    }

    static constexpr qint64 TimeoutMs = 30000;

    QTimer m_tick;
    QElapsedTimer m_clock;
    QString m_stage = QStringLiteral("window");
    QQuickWindow *m_window = nullptr;
    QJsonObject m_report;
};

} // namespace

class ProbePlugin : public QGenericPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QGenericPluginFactoryInterface_iid FILE "probe.json")

public:
    QObject *create(const QString &key, const QString &) override
    {
        return key.compare(QLatin1String("matomeprobe"), Qt::CaseInsensitive) == 0 ? new Probe
                                                                                   : nullptr;
    }
};

#include "Probe.moc"
