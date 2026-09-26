#include "FakeCore.h"

#include <QCommandLineParser>
#include <QCoreApplication>
#include <QHostAddress>
#include <QTextStream>

// The e2e backend: FakeCore on loopback, driven over HTTP under /__e2e/.
// `--port 0` takes any free port. The first stdout line is the readiness
// signal: "fakecore http://127.0.0.1:<port>".
int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("Matome Core stand-in for e2e tests"));
    parser.addHelpOption();
    const QCommandLineOption portOption(
            QStringLiteral("port"),
            QStringLiteral("Port on 127.0.0.1 (default 7011; 0 = any)."), QStringLiteral("port"),
            QStringLiteral("7011"));
    parser.addOption(portOption);
    parser.process(app);

    const QString wanted = parser.value(portOption);
    bool ok = false;
    const uint port = wanted.toUInt(&ok);
    matome::test::FakeCore core;
    if (!ok || port > 65535 || !core.listen(QHostAddress::LocalHost, quint16(port))) {
        QTextStream(stderr) << "fakecore: could not bind 127.0.0.1:" << wanted << "\n";
        return 1;
    }
    QTextStream(stdout) << "fakecore " << core.url() << Qt::endl;
    return app.exec();
}
