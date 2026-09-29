# Organization administration

After signing in, click the account at the bottom right of the explorer and
choose **Settings**. The command sheet also offers **Settings**, including
when no organization is open or the current membership is not an admin.
**Appearance** contains theme and language preferences, which apply to the
app and persist independently of an organization. **Back to files** or
Escape returns to the explorer at the same space and folder.

**Organizations** is always available in Settings and lists the signed-in
account's memberships. **Configure** opens the administration sections for
an organization where the account is an owner or admin. Selecting a different
organization clears pending confirmations and responses from the previous
one. **Open organization** returns to that organization's explorer, while
**Open organizations** returns to the explorer's organization list.

Selecting an organization as an owner or admin adds its administration
sections to Settings. This also changes the explorer's selected organization;
closing Settings returns to that selection.

The panel includes:

- Organization: edit the organization name using its current revision.
- Members: list active members, change their system role, and remove access.
- Invitations: send an email invitation, inspect its status and expiry, and
  cancel a pending invitation. Owner is available for existing members but
  cannot be assigned through invitations.
- Usage: inspect the plan and storage, member, guest, and space limits.
  Confirmed usage and reservations are shown separately.

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
responses. Losing admin membership returns Settings to Organizations; signing
out closes Settings.

For local validation, run `mise run studio` and sign in to a local Core as
an organization owner or admin. Verify Appearance without an open
organization, selection through Organizations, all four administration
sections, confirmations, return navigation, and a narrow window. The unit checks are available with
`mise run test:core`; QML lint is `mise run lint`.
