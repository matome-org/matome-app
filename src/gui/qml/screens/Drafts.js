.pragma library

// Edited add-on settings, shared by the organization's settings on an
// add-on's page and a space's own on the space's page.

// The organization's value of setting `key` of `product`: its installation's,
// else the catalog default.
function organizationValue(product, key) {
    const saved = product?.installation?.settings?.[key]
    return saved === undefined || saved === null ? product?.settings_schema?.[key]?.default ?? null : saved
}

// `drafts` with `key` at `value`, or without it when that is the `saved` value.
function edited(drafts, key, value, saved) {
    const next = Object.assign({}, drafts)
    if (JSON.stringify(value) === JSON.stringify(saved) || ((value === null || value === undefined) && (saved === null || saved === undefined)))
        delete next[key]
    else
        next[key] = value
    return next
}

// `flags` with `key` marked invalid unless `valid`.
function flagged(flags, key, valid) {
    const next = Object.assign({}, flags)
    if (valid) delete next[key]
    else next[key] = true
    return next
}
