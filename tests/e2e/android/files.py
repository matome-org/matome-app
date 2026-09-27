"""3 Files: uploads through Android's own picker, progress, failures,
download, rename, trash, restore, purge, cut and paste, and cycles."""

from __future__ import annotations

import re

from app import APP_DOWNLOADS, CYCLE, EMPTY_FOLDER, SERVER, App, scenario, sha256
from device import PACKAGE, expect

# Every byte value, so a lossy read of the content:// stream shows.
BINARY = bytes(range(256)) * 40


def landed(app: App, title: str, data: bytes) -> None:
    doc = app.core.document(title)
    expect(doc and doc["content_sha256"] == sha256(data),
           f"{title} did not land byte for byte: {doc}")


@scenario("3.1", title="upload one file through the system picker, byte for byte")
def upload_one(app: App) -> None:
    name = app.push("one.bin", BINARY)
    app.inbox()
    app.fab("upload")
    app.pick(name)
    app.wait_rows(["Docs", "root.txt", name])
    landed(app, name, BINARY)
    expect(app.core.document(name)["folder_id"] is None, "the upload missed the open folder")


@scenario("3.2", title="upload several files at once: a long press selects in the picker")
def upload_many(app: App) -> None:
    files = {app.push(f"many-{i}.txt", f"file {i}\n".encode() * (i + 1)): i for i in range(3)}
    app.inbox()
    app.open("Docs")
    app.menu("a.txt", "upload")
    app.pick(*files)
    app.device.wait(lambda s: s if sorted(app.rows(s)) == sorted(["Deep", "a.txt", *files]) else None,
                    "the uploaded rows")
    folder = app.core.folder("Docs")["id"]
    for name, i in files.items():
        landed(app, name, f"file {i}\n".encode() * (i + 1))
        expect(app.core.document(name)["folder_id"] == folder, f"{name} is not in Docs")


@scenario("3.4", title="uploads show which file of how many and its progress")
def upload_progress(app: App) -> None:
    d = app.device
    names = [app.push(f"slow-{i}.bin", BINARY) for i in (1, 2)]
    app.inbox()
    app.core.fail("/uploads$", method="POST", mode="hold", count=2)
    app.fab("upload")
    app.pick(*names)
    for index in (1, 2):
        app.until_held()
        d.label("uploadProgress", f"Uploading {index} of 2 · 0%")
        app.core.release()
    d.gone("uploadProgress")
    app.wait_rows(["Docs", "root.txt", *names])
    for name in names:
        landed(app, name, BINARY)


@scenario("3.5", title="a failed upload names the file and why; nothing half-stored")
def upload_failures(app: App) -> None:
    # Each file has its own name: a failed upload leaves its document, which holds it.
    faults = [(app.push(file, b"bad"), *fault) for file, *fault in (
        ("server.txt", "/uploads$", "POST", "status", 500, 1, SERVER),
        ("dropped.txt", "^/files/", "PUT", "drop", 0, 2, "Core or storage could not be reached."),
        ("refused.txt", "/complete$", "POST", "status", 422, 1, "Core refused it."))]
    app.inbox()
    for name, path, method, mode, status, count, why in faults:
        app.core.fail(path, method=method, mode=mode, status=status, count=count,
                      error="verification_failed")
        app.fab("upload")
        app.pick(name)
        app.device.gone("uploadProgress")
        app.failed(f"Could not upload “{name}”: {why}")
        expect(not app.core.state()["faults"], f"the upload never met the {method} {path} fault")
        expect(app.core.document(name)["content_sha256"] is None, f"the failed upload of {name} stored bytes")


@scenario("3.6", title="download saves the file and hands it to a viewer")
def download(app: App) -> None:
    d = app.device
    app.inbox()
    app.menu("root.txt", "download")
    d.gone("homeLink")
    activities = d.shell("dumpsys", "activity", "activities")
    expect(re.search(rf"act=android\.intent\.action\.VIEW dat=content://{re.escape(PACKAGE)}\.qtprovider/"
                     r"\S*/Download/root\.txt", activities), "no VIEW intent for the saved file")
    saved = d.adb("exec-out", "cat", f"{APP_DOWNLOADS}/root.txt", binary=True).stdout
    expect(saved == b"root bytes", f"the saved file holds {saved!r}")
    d.back()
    app.here("Inbox")


@scenario("3.7", title="rename in place from the long-press menu")
def rename(app: App) -> None:
    d = app.device
    app.inbox()
    for old, new, kind in (("root.txt", "notes.txt", "document"), ("Docs", "Papers", "folder")):
        app.menu(old, "rename")
        d.wait(lambda s, o=old: s if (e := s.get("rowEditor")) and e.text == o and e.focused else None,
               f"the editor on {old}")
        d.type(new)
        d.wait(lambda s, n=new: s if s.get("rowEditor").text == n else None, f"{new} typed over {old}")
        d.enter()
        d.gone("rowEditor")
        app.row(new)
        state = app.core.state()
        names = [doc["title"] for doc in state["documents"]] if kind == "document" \
            else [f["name"] for f in state["folders"]]
        expect(new in names and old not in names, f"Core still names the {kind} {old}")
    app.wait_rows(["Papers", "notes.txt"])


@scenario("3.8", "3.9", "3.10", title="trash, restore, and purge from the menus and the sheet")
def trash(app: App) -> None:
    d = app.device
    app.inbox()
    app.menu("root.txt", "trash")
    app.wait_rows(["Docs"])
    expect([doc["title"] for doc in app.core.state()["trash"]] == ["root.txt"], "root.txt is not in the trash")
    app.status("Moved to trash. Restore brings it back.")

    app.menu(None, "restore")
    app.wait_rows(["Docs", "root.txt"])
    expect(not app.core.state()["trash"], "the trash kept root.txt")

    app.menu("root.txt", "trash")
    app.wait_rows(["Docs"])
    app.account("sheet")
    d.showing("sheetQuery")
    d.tap(d.wait(lambda s: s.labelled("Purge last trash"), "purge in the sheet"))
    d.gone("sheetQuery")
    d.wait(lambda s: s if not app.core.state()["trash"] else None, "the purge")
    expect(app.core.document("root.txt") is None, "root.txt came back")
    menu = app.long_menu(app.blank())
    expect("restore" not in app.menu_items(menu), "restore is offered after the purge")


@scenario("3.11", title="cut and paste move a file and a folder, from the menus")
def cut_and_paste(app: App) -> None:
    app.inbox()
    app.menu("root.txt", "cut")
    app.status("Cut. Paste moves it into the open folder.")
    app.open("Docs")
    app.fab("paste")
    app.wait_rows(["Deep", "a.txt", "root.txt"])
    docs = app.core.folder("Docs")["id"]
    expect(app.core.document("root.txt")["folder_id"] == docs, "root.txt did not move into Docs")

    app.menu("Deep", "cut")
    app.device.tap("upButton")
    app.here("Inbox")
    app.menu("Docs", "paste")
    app.wait_rows(["Docs", "Deep"])
    expect(app.core.folder("Deep")["parent_id"] is None, "Deep did not move up to Inbox")


@scenario("3.14", title="a folder cannot be pasted into itself or below itself")
def folder_cycle(app: App) -> None:
    d = app.device
    app.inbox()
    app.menu("Docs", "cut")
    app.open("Docs")
    app.fab("paste")
    app.failed(CYCLE)
    app.open("Deep")
    expect(d.dump().get("emptyState").label == EMPTY_FOLDER, "Deep shows the error from Docs")

    for above in ("Docs", "Inbox"):
        d.tap("upButton")
        app.here(above)
    app.menu("Docs", "cut")
    app.open("Docs", "Deep")
    app.menu(None, "refresh")
    d.label("emptyState", EMPTY_FOLDER)
    app.fab("paste")
    d.label("emptyState", CYCLE)
    expect(app.core.folder("Docs")["parent_id"] is None, "Docs moved into its own tree")
