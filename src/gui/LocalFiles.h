#pragma once

#include <QtGlobal>

#ifdef Q_OS_WASM
#include <QByteArray>
#include <QString>
#include <QtGui/private/qwasmlocalfileaccess_p.h>

#include <functional>
#include <list>
#include <memory>

namespace matome {

// QML's FileDialog cannot read the visitor's disk; the browser's picker
// hands over each chosen file's name and bytes, one after another.
inline void pickLocalFiles(const char *accept, std::function<void(const QString &, const QByteArray &)> each)
{
    auto picked = std::make_shared<std::list<std::pair<QString, QByteArray>>>();
    QWasmLocalFileAccess::openFiles(
            accept, QWasmLocalFileAccess::FileSelectMode::MultipleFiles, [](int) {},
            [picked](uint64_t size, const std::string &name) {
                picked->emplace_back(QString::fromStdString(name),
                                     QByteArray(qsizetype(size), Qt::Uninitialized));
                return picked->back().second.data();
            },
            [picked, each] {
                const auto [name, bytes] = picked->front();
                picked->pop_front();
                each(name, bytes);
            });
}

} // namespace matome
#endif
