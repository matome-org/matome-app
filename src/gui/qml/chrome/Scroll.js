.pragma library

// Scrolls `flick` the least that shows `rect` of `item` (all of it when
// `rect` is null) with `margin` to spare. Items outside `flick` are left.
function reveal(flick, item, rect, margin) {
    let at = item
    while (at && at !== flick.contentItem)
        at = at.parent
    if (!at)
        return
    const area = rect ?? Qt.rect(0, 0, item.width, item.height)
    const top = item.mapToItem(flick.contentItem, area.x, area.y).y
    const bottom = top + area.height
    // Taller than the view and already in it: nothing to bring into sight.
    if (bottom - top > flick.height && top < flick.contentY + flick.height && bottom > flick.contentY)
        return
    const first = -flick.topMargin
    const last = Math.max(first, flick.contentHeight + flick.bottomMargin - flick.height)
    if (top - margin < flick.contentY)
        flick.contentY = Math.max(first, top - margin)
    else if (bottom + margin > flick.contentY + flick.height)
        flick.contentY = Math.min(last, bottom + margin - flick.height)
}
