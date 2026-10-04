# Organization administration

After signing in, click the account at the bottom right of the explorer and
choose **Settings**. The command sheet also offers **Settings**, including
when no organization is open or the current membership is not an admin.
**Appearance** contains theme and language preferences, which apply to the
app and persist independently of an organization. **API tokens** manages the
signed-in user's personal tokens; see [API tokens](#api-tokens). **Back to
files** or Escape returns to the explorer at the same space and folder.

The sidebar lists every organization with its name and the administration
sections its action catalog opens to the signed-in person (see
[What Settings opens](#what-settings-opens)). Choose a section under an organization to
select it and open that page directly. The active page is highlighted under
its organization. A narrow window exposes the same navigation in a drawer.
**Appearance** and **API tokens** remain global entries above the organizations. Click an
organization's name or arrow to expand or collapse its submenus. Enter or
Space toggles the group; Right expands it and Left collapses it. The current
organization starts expanded when Settings opens. Expansion state survives
list refreshes and switching between the sidebar and the narrow drawer
while Settings stays open. Collapsing a group keeps the current page open.

The navigation is one stop in the Tab order: Tab lands on its selected row,
and the next Tab goes to the section's content. Up and Down move between its
rows without choosing one, Home and End go to the first and last, and Enter
or Space chooses. Reloading the organizations or their spaces (entering
People, a save, the window coming back to the front) keeps the rows on
screen, so the focus and a click under way stay where they were.

Selecting a different organization clears pending confirmations and
responses from the previous one. **Open organization** returns to that
organization's explorer, while **Open organizations** returns to the
explorer's organization list. Selecting an organization also changes the
explorer's selection; closing Settings returns to that selection.

The panel includes:

- General: **Rename organization** opens a side panel with the name, saved
  with its current revision.
- People: two tabs, one [table](#tables) at a time: **Members** (name,
  built-in roles) and **Invitations** (email, roles, status and expiry, the
  spaces it offers access to). **Open** opens the member's or invitation's
  page selected; see [People](#people). **New user** creates an account the
  organization manages; see [New user](#new-user). **Invite** opens the
  panel to invite someone; see [Invitations](#invitations). Core does not
  push membership changes, so People reloads when it is entered and when
  the window comes back to the front.
- Groups, Roles, Spaces, and Tags: see [Access](#access).
- Usage: inspect the plan and storage, member, guest, and space limits.
  Confirmed usage and reservations are shown separately.
- Add-ons: a [table](#tables) of the add-ons with their status and the
  number of spaces where each is active; **Open** opens the
  [page](#detail-pages) of the one selected. Its tabs: **Details**, its
  status and its organization settings read only; **Spaces**, a table of
  every space where it works, active or not; and **Roles**, a table of the
  roles it adds and what each allows, whose **Open** opens the role's page
  under Roles. Installing makes it available in every space of the
  organization, including later ones, and active in none. The page's own
  commands open a side panel for each change:
  **Install** asks only its settings, then **Install**; required settings,
  such as the classifier's tags, must be filled first, and a list setting
  adds one entry at a time with Enter or **Add**. **Settings** changes the
  organization settings, **Plan and usage** shows the SKU, version,
  purchased and assigned quantities and allowance and, for a billing
  manager with a live subscription, sets the purchased quantity. **Pause**
  and **Uninstall** say first how many people and groups hold each of its
  roles and in how many spaces it stops; uninstalling controlled documents
  asks a reason. **Resume** sends the saved settings back at once. Core
  makes the installer the responsible member, the membership an add-on
  calling Core through a trusted webhook acts for; **Responsible member**
  changes it, shown only for such an add-on (Core does not flag them, so
  the app treats an add-on that works per space and declares no action of
  its own as one). Core marks an uninstalled add-on `uninstalled`: its row
  and page show **Not installed** and **Install** again, which Core answers
  by reactivating the installation and its space activations. Core keeps
  the grants of its roles for that reinstall but no longer lists them on
  spaces, folders, or documents. A reload asked for while the add-ons
  load, such as after creating a space, runs once that load ends.
  **Activate** (or **Settings**, once active), the **Spaces** tab's
  command, opens the panel that turns the add-on on or off in the space
  selected with its space settings, the same panel a space's page opens;
  for [controlled documents](controlled-documents.md) it is whether the
  space requires reviews.

Removals, archiving, and invitation cancellations ask first, in a side
panel of their own.
Core enforces authorization, plan limits, and the last-owner constraint.
Failed requests remain visible in the relevant section or action message.
Refresh reloads the panel; a name revision conflict also reloads the current
organization before another save.

### What Settings opens

Settings follows the person's effective actions, whatever gives them: a
built-in role, a custom role, or a role held through a group. The app reads
each organization's action catalog (`GET action-catalog`, without
`space_id`) when the organizations are listed, again on refresh, after a
change in Settings, and when Settings closes. A section opens for whoever
holds one of the actions that manage it there:

| Section | Actions |
| --- | --- |
| General | `organization.update_policy` |
| People | `membership.create`, `membership.invite`, `principal_role.grant` |
| Groups | `group.create`, `group.update`, `group.membership_change` |
| Roles | `role.create`, `role.update`, `principal_role.grant` |
| Spaces | `resource_grant.read` |
| Tags | `tag.create`, `tag.update` |
| Usage | `usage.read` |
| Plan and billing | `billing.read` |
| Add-ons | `add_on.read` |

Inside a section every command stays in its bar; one the catalog refuses
is unusable and says what is missing (see [Refusals](#refusals)): Rename
organization (`organization.update_policy`), New user and New setup code
(`membership.create`), Invite (`membership.invite`), Cancel invitation
(`membership.invite_cancel`), Manage roles (`principal_role.grant`), New
group, Rename, Archive, and Manage members or groups (`group.create`,
`group.update`, `group.archive`, `group.membership_change`), New role,
Copy, Edit permissions, and Archive (`role.create`, `role.update`,
`role.archive`), New tag, Edit, Restrict, and Archive (`tag.create`,
`tag.update`, `tag.archive`), a space's Rename and Archive
(`space.update_metadata`, `space.archive` in that space), Manage billing
and Subscribe
(`billing.manage`), and an add-on's Install, Resume, Pause, Uninstall,
Settings, and Responsible member (`add_on.install`). The add-ons are read
for whoever holds `add_on.read`.

Every operation still uses the authenticated Core endpoint, which checks
effective permissions. Read failures clear the affected collection and
disable its mutations. A section the catalog no longer opens, an
organization switch, or a sign-out clears organization data and
invalidates pending responses; Settings returns to Appearance, and signing
out closes it.

### Refusals

Before an action, the app says what is missing, from what Core lists:

- the space's action catalog (`GET action-catalog?space_id=`: `allowed`,
  `product_key`, `axis`, `resource_grant`), or the organization's for an
  organization action;
- the add-on's entitlement and installation (`GET entitlements`,
  `GET add-ons`), for whoever reads the add-ons;
- the add-ons of the space (`GET spaces/:id/add-ons`), where the person may
  turn them on;
- the roles and their actions (`GET roles`).

The first that refuses is said: **The plan does not include Controlled
documents.**, **Controlled documents is not installed in the
organization.**, **… is paused in the organization.**, **… is not active in
this space.**, or the narrowest roles that hold the action: **You need
Controlled documents manager in this space.** (or **in the organization**).
Where the space's add-ons are not readable, the role is named with the
add-on: **You need … in this space, with … active here.** A disabled
command shows it as its tooltip and accessible description, and the same
words follow a Core `forbidden` when the catalog explains it; Core's own
text is the last resort.

Where the person may carry it out from Settings, the command that fixes it
stands beside the refused one: **Grant access** opens the space's page in
Settings with its Grant access panel, the narrowest role that holds the
action ticked; **Activate** opens the space's page with the add-on's
activation panel; **Open plan** opens Plan and billing; **Install** and
**Resume** open the add-on's page. **Grant access** needs
`resource_grant.create` in the space, **Activate** `add_on.space_activate`
there, both the Spaces section; **Open plan** needs `billing.manage`;
**Install** and **Resume** need `add_on.install`.

## Access

Access follows the users, teams, and security roles of an admin center:
each section is one [table](#tables) whose rows are read only, under one
command bar, and **Open** (or Enter, or a double click) opens the
[page](#detail-pages) of the row selected. A person or group holds any
number of roles, and a role is a named set of permissions. Sections that
create entries show **New user** and **Invite**, **New group**, **New
role**, or **New tag** beside **Open**, which open a
[side panel](#side-panel).

- Groups: name and member count; see [Groups](#groups).
- Roles: name, type, and where it applies; see [Roles](#roles).
- Spaces: name and whether the space is archived. A space's page:
  - commands: **Rename** (`PATCH spaces/:id` with the name) and
    **Archive**, which asks, then sends `POST spaces/:id/archive`; an
    archived space stays listed and readable, and both commands then say
    **It is archived.** Core has no route that the app uses to reactivate
    one here;
  - **Details**: its name, whether it is active or archived, and its
    visibility, Public or Private, from Core's access summary;
  - **Access**: see [Resource access](#resource-access); its commands are
    **Grant access**, **Manage roles**, **Remove**, and **Check access**;
  - **Add-ons**: every installed add-on that works per space with whether
    it is active there. An active add-on whose roles nobody given access
    to the space holds reads **Active · nobody holds its roles here**.
    **Activate** (**Settings** once active) opens the panel that turns the
    add-on on or off there with its space settings (see
    [controlled documents](controlled-documents.md#configure)); **Open**
    opens its page under Add-ons.
- Tags: name and whether it restricts; **New tag** names a tag in the
  panel and may restrict it. A tag's page has the commands **Edit** (its
  name), **Restrict** or **Stop restricting** (saying what that does to
  tagged documents), and **Archive**, each a panel, and the tabs
  **Details** (its name and whether it restricts its documents) and
  **Access**, whose commands are **Grant access**, **Manage roles**, and
  **Remove**. A restricted tag hides its documents from everyone without
  access to the tag; its access is given to members, groups, or everyone
  holding a role.

### Detail pages

Every item opens on the same page. Its top line is the way back, named
after the list (**People**, **Groups**, **Roles**, **Spaces**, **Tags**,
**Add-ons**), the item's name, and one command bar. Below are its tabs;
the first, **Details**, holds read-only facts and no table, and every
related list is a tab of its own holding exactly one table. The bar holds
the item's own commands and, after a hairline, the commands of the tab
shown, which act on that tab's rows selected; switching tabs swaps them,
and the item's own commands stay. A command never disappears: one that
does not apply stays, unusable, saying why. Every command opens a side
panel. A window too narrow for the name and the bar on one line puts the
bar under the name, which keeps its full width; a bar too wide for its
labels shows only icons, each naming itself in a tooltip.

The way back (or Escape, once no panel is open) returns to the list, focus
on the page's row. Opening a page moves focus to it and shows **Details**;
a page opened to show access (a space or tag from a person's Access tab, a
fix, or the explorer) opens on its **Access** tab. **Open** on a tab opens
the person, group, role, or place of the row selected in its own section.

In the explorer, **New space** (N at the organization's spaces) opens a side
panel with the space's name and its visibility, **Private** (only people
given access) or **Public** (every member except guests reads it), which
Core requires at creation; Private is checked first. **Create space** sends
`POST spaces` with both.

In the explorer, **Manage access** (A, or the entry's menu) opens the access
page of the focused folder or document in place of the list, on its
**Access** tab, with the same commands and side panels as in Settings; keys
other than Tab, F6, and Escape stay on the page. **Back to files** or
Escape returns to the entry. Its commands are **Stop inheriting** (or
**Change inheritance**), **Restore inheritance**, and **Check access**; its
tabs are **Details** (how it inherits, and whether every member except
guests reads it) and **Access**. Opening an inherited row (Enter or a
double click) opens the folder it comes from on the same page, or the
space's page in Settings.

The explorer reads Core's action catalog for the current space
(`GET action-catalog?space_id=`) on entering it and on refresh. When the
catalog allows listing the space, it speaks for the space: upload, new
folder, download, rename, move, trash, and **Manage access** follow what it
allows, and one it refuses says why (see [Refusals](#refusals)). Access
held only on folders or documents is not judged there, so those actions
stay offered and Core decides.

### Tables

Every list that something acts on is the same table: a header naming the
columns over read-only rows whose cells end in an ellipsis when long; the
command bar that acts on the rows selected is the section's, or the
page's. Rows hold no buttons, pickers, or inputs. The rows are one stop in the Tab order; reaching them by keyboard
selects the row under the cursor. Up and Down, Home and End, and PageUp
and PageDown move the cursor and select that row; Enter or Space opens it,
as **Open** does; a click selects one row and a double click opens it. In
a table where several rows may be removed at once (Access, a person's or
group's access, a role's holders), Shift with the arrows, Home, End, or
the page keys extends the selection, Ctrl+Space or a Ctrl click toggles a
row, a Shift click selects a range, a right click or a long press toggles
a row, and Ctrl+A selects them all. The page around a table scrolls with
the wheel, and the cursor stays in sight.

A command that does not apply stays in its bar, unusable, and says why
when hovered or reached by Tab (**Select one row.**, **Only custom roles
can be archived.**, **It is not installed.**, or what the person lacks, see
[Refusals](#refusals)); screen readers read the reason as its description.
Only a command for another kind of resource is left out, such as
inheritance on a space or Check access on a tag.

### Side panel

The panel slides in at the right of the list or page it opens from, and
covers it on a narrow window. It holds a title, the step's controls, and
**Cancel** with the step's **Save**. Opening it moves focus into it;
closing it returns focus to the row or button it was opened from. Escape or
**Cancel** first steps back out of a confirmation or a picker, then closes
it. Each panel does one job. Destructive changes (removing a member or
access, archiving, cancelling an invitation, revoking a token, selecting a
billing package) are a panel that names what is lost before its button;
there are no dialogs. Keys other than Tab stay in the panel while it has
focus; the page beside it stays usable with the mouse, touch, Tab, and the
wheel. A save that lands closes the panel and shows its notice on the page,
one notice naming the last change saved (**Roles saved.**, **Groups
saved.**, **Group renamed.**, **Tag restricted.**); a refusal stays in the
panel with what was entered, shown there once, and goes when the field it
names changes.

### People

A member's page has the commands **Manage roles**, **Manage groups**,
**New setup code**, and **Remove from organization**, and the tabs:

- **Details**: how they sign in (their email, or `org-slug/username` for
  an account the organization manages, the slug coming from
  `GET organizations/:id`), their name, and whether the account is
  personal or managed by the organization.
- **Roles** and **Access**: what they hold; see
  [Held access](#held-access).
- **Groups**: a table of the groups they belong to, with **Open**.

The commands:

- **Manage roles**: every role given across the organization as a
  checkbox: the built-in ones (Owner, Administrator, Member, Billing,
  Guest) first, then the custom roles that work there; place-only roles
  (see [Roles](#roles)) are not offered, and one already held stays. Save
  makes the checked roles exactly their
  organization roles: it sends `POST principal-roles` for each role added,
  then `DELETE principal-roles/:id` for each one taken back, so a member
  never passes through holding none. Core's refusals show in the panel:
  only an owner gives or takes Owner, the organization keeps one member
  holding Owner directly (`last_owner`), and a role moving a member to a
  guest seat needs the plan's guests capability.
- **Manage groups**: every group as a checkbox, saved with
  `POST groups/:id/members` and `DELETE groups/:id/members/:membership_id`
  for each group joined or left.
- **New setup code**, usable for a managed account only: asks, then sends
  `POST members/:id/setup-code` and shows the new code and its expiry once.
  The previous code stops working; the current password keeps working until
  the code is used.
- **Remove from organization**: says in how many places access given to
  them directly ends
  and names the groups they leave and their custom and add-on roles, then
  sends `DELETE members/:id`; Core takes all their organization roles.
- **Grant access** (Access tab): pick a space or a tag, then **Next** and
  the roles they get there; sends one `POST …/grants` per role they do not
  hold there yet. Folders and documents are given from their own access
  page.
- **Remove** (Roles and Access tabs): for the rows selected that were
  given to them directly, names each role and place, then sends
  `DELETE principal-roles/:id` for an organization role and
  `DELETE …/grants/:id` for a grant. A row that reaches them through a
  group or a role, or a place open to members, is removed where it comes
  from; the command says so.
- **Open** (Roles and Access tabs): the role's page, or the place's
  access.

### New user

**New user** creates an account the organization manages, which signs in
as `org-slug/username`. The panel asks the username (2 to 64 lowercase
letters, digits, dots, hyphens, or underscores; Core stores it lowercase),
an optional name, its built-in organization roles (Administrator, Member,
Billing, Guest; Member checked first), and an optional password of 8 to 72
characters, and sends `POST members`. Core refuses a taken username
(`username_taken`) or an invalid one (`invalid_username`), and the panel
says so. With a password the account signs in at once and the panel
closes. Without one, Core answers a one-time setup code and its expiry,
which the panel shows once with the sign-in, selectable to copy; the person
finishes with the code on the sign-in screen. Closing the panel forgets the
code.

### Groups

A group's page has the commands **Manage members**, **Manage roles** (as
for a person), **Rename**, and **Archive**, and the tabs **Details** (name
and member count), **Members** (a table with **Open**), and **Roles** and
**Access** as for a person (`GET principal-roles?group_id=`,
`GET groups/:id/access`), with the same commands.

- **Manage members**: a searchable checklist of every member; Save leaves
  exactly the checked ones in the group, adding and removing only what
  changed.
- **Rename**: the name, saved with `PATCH groups/:id`.
- **Archive**: asks, then sends `POST groups/:id/archive` and returns to
  the list.

**New group** asks only the name; once created, the group's page opens.

### Roles

Roles is a table of every role: its name, its type (built-in, add-on, or
custom), and where it applies (organization or spaces). Settings' command
bar holds **New role** and **Open**; Copy and Archive are on the role's
page. A holder count is not shown: Core lists a
role's holders only one role at a time (`GET roles/:id/holders`), so the
table would read every role on each visit. Organization roles are the built-in Owner,
Administrator, Member, Billing, and Guest, and the custom and add-on roles
holding an organization permission; they are given to people and groups
across the organization. Space roles are Core's built-in atomic and broad
roles and the custom and add-on roles holding only space permissions; they
are granted on spaces, folders, documents, and tags.

Each role is offered only where it works. Core reads an action the catalog
marks `resource_grant` only from a grant on the place, so a role holding
one and no organization action, every add-on role among them, is
place-only: it is not offered in Manage roles or in a role's Add people
across the organization, only in Grant access on a space, folder,
document, or tag. Decided from the catalog, not by name; the built-in
organization roles always work across it. A place-only role Core still
lists as given across the organization shows **Organization · no effect
there** as where it holds, on the person's or group's Roles tab and the
role's Assigned to, so it can be removed.

A role's page has the commands **Edit permissions**, **Copy**, and
**Archive**, and the tabs **Details** (type, where it applies, how many
permissions), **Permissions**, a table of what it allows (area and
permission, grouped by area), and **Assigned to**, a table of who holds it,
from `GET roles/:id/holders`: the holder (a person, a group, or everyone
holding a role, on a tag), its kind, and where: **Organization** for a role
given across the organization, else the space, folder, document, or tag of
a grant. Core lists only grants on places whose access the signed-in
person may read, and names each holding directly, so whether a person
holds it through a group is not shown. The commands:

- **Edit permissions**, usable for custom roles only: the name and the
  permissions, saved with `PATCH roles/:id` for every holder.
- **Copy**: opens **New role** with the role's permissions and **Copy of**
  its name.
- **Archive**, usable for custom roles only: asks, then sends
  `POST roles/:id/archive` and returns to the list.

The **Assigned to** tab's commands:

- **Add people**: a searchable checklist of people and groups. A role that
  applies to the organization lists those not holding it, and **Add**
  sends one `POST principal-roles` for each. A role that applies to spaces,
  or a place-only one, add-on roles included, asks next for the space (**Next**), and **Add**
  sends one `POST spaces/:id/grants` for each person or group not holding
  it there yet. Folders and documents are given from their own access page.
- **Remove**: names how many holders lose it, then sends
  `DELETE principal-roles/:id` for a role given across the organization and
  `DELETE …/grants/:id` for a grant on its place.
- **Open**: the person's, group's, or role's page.

**New role** asks a name, whether it applies to the organization or to
spaces, and its permissions: a space role picks among space permissions, an
organization role among all of them, its space permissions holding in
every space. **Create role** sends the name, the chosen actions, and a
generated `custom-<uuid>` key, since Core requires a key that is unique in
the organization, archived roles included. Actions Core marks
`system_only` are not offered, and a copy leaves them out. An add-on's
actions (`addon.<product>.<verb>`) form one area named after the add-on.
Installing an add-on makes Core add the roles its product declares (origin
`add_on`); they are read only, granted on places, and archived while the
add-on is paused or uninstalled, keeping their holders.
Owner and admin do not receive their actions without an explicit grant.
Role keys under `addon.` are reserved.

### Held access

A member's or group's page shows what they hold in two tabs. **Roles** is
a table of each organization role, from `GET principal-roles`, with
**Organization** as where (**Organization · no effect there** for a
place-only role). **Access** is a table with the columns Place, Roles, and
Source, one row per place and way it reaches them: each grant that reaches
them, from `GET members/:id/access` or `GET groups/:id/access`, its roles
on that place joined; and, for a member, each public space or open folder
or document they read through their organization roles (the page's
`open`), as **Reads**. Core
lists the grants on spaces, folders, documents, and tags whose access the
signed-in person may read; a member's include their groups' grants and the
tag grants of roles they hold. The source is **Direct**, **Through the
group** or **Through the role**, or **Open to members**. Folders and
documents are named in their space; a name Core does not give is read once
with `GET spaces/:space_id/folders/:id` or `…/documents/:id`. **Open**
opens a role's page, or a place's access: a space or a tag on its Access
tab under Spaces or Tags, a folder or document as a page whose way back,
named after the person or group, returns to their page.

### Invitations

**Invite** opens the panel with the email, the organization roles they get
on acceptance (Administrator, Member, Billing, Guest; Member checked
first; at least one), sent as `roles`, and, optionally, access to spaces:
check a space, then the roles they get there. Owner cannot be offered.
Each checked space needs at least one role. The roles are sent as the
invitation's grants (`grants: [{space_id, role_ids}]` on
`POST invitations`). Core checks each space as it checks a `PUT …/grants`
there and refuses the whole invitation if one fails: a space or role that
is gone, a space where the inviter may not give access, or a space without
room for more grants under the plan. On acceptance Core gives the new
member those roles as the inviter; a space the inviter can no longer give
is skipped. A refusal shows once in the panel and clears when the email
changes.

An invitation's page has the command **Cancel invitation**, usable while
it is pending, which asks, then sends `POST invitations/:id/cancel`, and
the tabs **Details** (status, expiry, and organization roles) and **Access
to spaces**, a table of each space it offers with the roles chosen there,
whose **Open** opens the space.

### Resource access

A space, a folder, a document, and a tag show who has access the same way:
the **Access** table, a row per person, group, or role principal with the
roles they hold there and where it comes from: **Given here**, or, on a
folder or document, **From the space** or **From the folder** it inherits
from, outermost first, marked **manages access only** when it comes from
above a break in inheritance and only its access management reaches here.
A space, folder, or document reads `GET …/access`, whose rows carry their
`source`, whether they are `inherited`, and their `scope`, and whose
`summary` gives the space's visibility and how the item inherits; a tag
reads `GET tags/:id/grants`. A folder's or
document's **Details** tab shows **Inheritance** (from the space, from a
folder that stopped inheriting, or stopped, restricted or open to members)
and whether every member except guests reads it.

The commands, those on rows being the Access tab's:

- **Grant access**: the same panel on every resource. First pick people
  and groups (and, on a tag, everyone holding a role), with a search; then
  **Next** shows the roles on a step of their own, with a search, so none
  is pushed off the panel. **Grant access** sends one `PUT …/grants` per
  person or group picked that lacks one of the roles, with the roles they
  already hold there and the checked ones. The roles are Core's space
  roles, the eight atomic ones (Content reader, Content contributor,
  Content purger, Content sharer, Access manager, Space maintainer, Add-on
  manager, Automation manager) and the three broad ones (Content manager,
  Space operator, Space administrator), then the active add-on roles and
  the custom roles.
- **Manage roles**, on the one row selected, given here: every role a
  grant may carry, as a checkbox. **Save** sends one `PUT …/grants` with
  the holder and the checked role ids, which Core makes exactly the
  holder's roles there in
  one transaction, so a change lands whole or not at all; Core answers the
  holder's grants there, which take the place of the holder's row.
- **Remove**, on the rows selected, all given here: names the roles lost,
  then sends the same request with no role ids for each holder.
- Opening an inherited row (Enter or a double click), on a folder or
  document: opens the place it comes from, where it is changed.
- **Stop inheriting**, a folder's or document's own command: choose
  **Restricted** (only access given here and below) or **Open** (every
  member except guests also reads it); `PUT …/access` with that
  `inheritance`. Core copies no grant down, so the panel names who keeps
  access (those given access here, and those whose roles manage access from
  above) and who loses it. Once it stopped, the same command reads
  **Change inheritance** and switches straight between **Restricted** and
  **Open** with the same request. **Restore inheritance**, usable once it
  stopped, asks, then sends `inheritance: inherit`.
- **Check access**, a space's Access tab command and a folder's or
  document's own, never on a tag: pick a member to see what they may do
  here, by area, and why: each role given to them or to a group of theirs
  and where, an open space or folder, and owners and administrators
  managing access everywhere, directly or through a group. Core has no
  route for it: the app works it out from the rows listed here, the
  member's groups, their built-in organization roles and those of their
  groups (`GET principal-roles?group_id=` for each group, once per open
  place), and the roles' actions. On a document, each restricted tag on it
  counts too: the document's `tag_assignments` (`GET …/documents/:id`) and
  each tag's grants (`GET tags/:id/grants`), read with the access. A grant
  on the tag reaches the member when it names them, a group of theirs, or
  a role they hold (their own organization roles read with
  `GET principal-roles?organization_membership_id=`). Without one, the tag
  hides the document and every action on it, and the reason names it:
  **The restricted tag … hides it from them.**

Grants of archived roles, such as those of a paused or uninstalled add-on,
are left as they are. Core lists them only on tags, where they still grant
the tag; such a holder shows **Still granted through archived roles**.
Access to a space is decided only by grants on resources.

## API tokens

A personal API token lets a script or integration call Core as the signed-in
user. **New token** opens its page: a name, an expiry of 7, 30, or 90 days,
and its access. Access is added in steps: pick an organization, where the
actions apply (across the organization, every space the user can reach when
the token is used, or one space), and the actions, then **Add to token**.
The actions offered are those Core's action catalog allows the user at that
target; for every space, Core checks each space when the token is used.

Core makes a token only within 15 minutes of a password sign-in. Past that,
the page asks for the password, signs in again in place, and revokes the
replaced session. **Create token** shows the secret once, with **Copy**;
**Done** forgets it. Each token lists its prefix, expiry, last use, and
access; **Revoke** asks first in a side panel and takes effect on the
token's next request.

For local validation, run `mise run studio` and sign in to a local Core as
an organization owner or admin. Verify Appearance without an open
organization, selection through the organization sidebar, every administration
section, each page and its panels, return navigation by mouse and Escape,
and a narrow window. The unit checks are available with
`mise run test:core`; QML lint is `mise run lint`.
