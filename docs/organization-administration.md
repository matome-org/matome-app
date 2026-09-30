# Organization administration

After signing in, click the account at the bottom right of the explorer and
choose **Settings**. The command sheet also offers **Settings**, including
when no organization is open or the current membership is not an admin.
**Appearance** contains theme and language preferences, which apply to the
app and persist independently of an organization. **Back to files** or
Escape returns to the explorer at the same space and folder.

The sidebar lists every organization with its name and nested administration
sections for owners and admins. Choose a section under an organization to
select it and open that page directly. The active page is highlighted under
its organization. A narrow window exposes the same navigation in a drawer.
**Appearance** remains a global entry above the organizations. Click an
organization's name or arrow to expand or collapse its submenus. Enter or
Space toggles the group; Right expands it and Left collapses it. The current
organization starts expanded when Settings opens. Expansion state survives
list refreshes and switching between the sidebar and the narrow drawer
while Settings stays open. Collapsing a group keeps the current page open.

Selecting a different organization clears pending confirmations and
responses from the previous one. **Open organization** returns to that
organization's explorer, while **Open organizations** returns to the
explorer's organization list. Selecting an organization also changes the
explorer's selection; closing Settings returns to that selection.

The panel includes:

- General: edit the organization name using its current revision.
- Members: list active members, change their system role, and remove access.
- Invitations: send an email invitation, inspect its status and expiry, and
  cancel a pending invitation. Owner is available for existing members but
  cannot be assigned through invitations.
- Usage: inspect the plan and storage, member, guest, and space limits.
  Confirmed usage and reservations are shown separately.
- Add-ons: select an add-on, then install, resume, pause, or uninstall it
  and choose its spaces from the command bar.
- Spaces: pick a space from the dropdown to list who holds which role in it.
  **Grant access** opens a dialog to choose the member and the role;
  **Revoke access** removes the selected grant after confirmation. Add-ons
  that work per space, such as [controlled documents](controlled-documents.md),
  add their settings to this page.

Role changes, removals, and invitation cancellations require confirmation.
Core enforces authorization, plan limits, and the last-owner constraint.
Failed requests remain visible in the relevant section or action message.
Refresh reloads the panel; a name revision conflict also reloads the current
organization before another save.

The current API lists a membership's system role but does not expose the
caller's effective action set. This version limits organization sections
to `owner` and `admin`; custom roles or groups do not unlock these sections.
Every operation still uses the authenticated Core endpoint, which checks
effective permissions. Read failures clear the affected collection and
disable its mutations. A refreshed loss of admin membership, organization
switch, or sign-out clears organization data and invalidates pending
responses. Losing admin membership returns Settings to Appearance; signing
out closes Settings.

For local validation, run `mise run studio` and sign in to a local Core as
an organization owner or admin. Verify Appearance without an open
organization, selection through the organization sidebar, every administration
section, confirmations, return navigation, and a narrow window. The unit checks are available with
`mise run test:core`; QML lint is `mise run lint`.
