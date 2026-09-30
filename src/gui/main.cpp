#include "Session.h"
#include "Theme.h"
#include "references/AssetImages.h"

#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QUrl>

#ifdef Q_OS_ANDROID
#include <QKeyEvent>
#include <QWindow>

namespace {

// Android's Back is Esc: it closes what floats (menu, sheet, drawer, filter),
// drops an edit, returns to sign-in, then goes up a level. When nothing
// takes the Esc (the sign-in form, the root) Back goes on to Android, which
// leaves the app.
class BackIsEscape : public QObject
{
protected:
    bool eventFilter(QObject *watched, QEvent *event) override
    {
        if ((event->type() != QEvent::KeyPress && event->type() != QEvent::KeyRelease)
            || static_cast<QKeyEvent *>(event)->key() != Qt::Key_Back
            || !qobject_cast<QWindow *>(watched))
            return false;
        QKeyEvent escape(event->type(), Qt::Key_Escape, Qt::NoModifier);
        QCoreApplication::sendEvent(watched, &escape);
        return escape.isAccepted();
    }
};

} // namespace
#endif

int main(int argc, char **argv)
{
#ifdef Q_OS_ANDROID
    // SwiftShader on the emulator drops one triangle of batched
    // Rectangle geometry. Paint each fill separately.
    qputenv("QSG_NO_BATCHING", "1");
    qputenv("QSG_RENDER_LOOP", "basic");
    qputenv("ANDROID_OPENSSL_SUFFIX", "_3");
#endif

    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("matome-studio"));
    QGuiApplication::setOrganizationName(QStringLiteral("matome"));
    QGuiApplication::setQuitOnLastWindowClosed(true);
    QGuiApplication::setWindowIcon(QIcon(QStringLiteral(":/icons/matome.svg")));
#ifdef Q_OS_ANDROID
    BackIsEscape backIsEscape;
    app.installEventFilter(&backIsEscape);
#endif

    QQmlApplicationEngine engine;
    QObject::connect(&app, &QGuiApplication::lastWindowClosed, &app, [] {
        QCoreApplication::exit(0);
    });
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated, &app,
                     [](QObject *object, const QUrl &) {
                         if (!object)
                             QCoreApplication::exit(1);
                     },
                     Qt::QueuedConnection);
    // Theme first: it resolves the language and installs its translator
    // before any QML binding reads a string.
    engine.singletonInstance<matome::Theme *>(QStringLiteral("matome"), QStringLiteral("Theme"));
    matome::installAssetImages(engine, *engine.singletonInstance<matome::Session *>(QStringLiteral("matome"),
                                                                                 QStringLiteral("Session")));
    engine.load(QUrl(QStringLiteral("qrc:/qml/Main.qml")));
    if (engine.rootObjects().isEmpty())
        return 1;
    return app.exec();
}
