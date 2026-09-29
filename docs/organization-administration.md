# Organization administration

Open an organization as an owner or admin, then choose **Organization
administration** in the explorer sidebar or command sheet. On narrow
windows, open **Browse** to reach the sidebar. **Back to files** or Escape
returns to the explorer at the same space and folder.

The panel includes:

- General: edit the organization name using its current revision.
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
caller's effective action set. This version limits panel entry to `owner`
and `admin`; it does not grant panel entry through custom roles or groups.
Every operation still uses the authenticated Core endpoint, which checks
effective permissions. Read failures clear the affected collection and
disable its mutations. A refreshed loss of admin membership, organization
switch, or sign-out closes the panel and invalidates pending responses.

For local validation, run `mise run studio` and sign in to a local Core as
an organization owner or admin. Verify all four sections, confirmations,
return navigation, and a narrow window. The unit checks are available with
`mise run test:core`; QML lint is `mise run lint`.
