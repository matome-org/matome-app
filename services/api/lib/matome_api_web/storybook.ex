defmodule MatomeApiWeb.Storybook do
  @moduledoc """
  Design-system catalog (plan p2-core-backoffice, Phase A).

  The Elixir equivalent of the Flutter Widgetbook: a browsable gallery that
  renders the real HEEx base + composite components (`MatomeComponents`,
  `MatomeComposites`) as a visual drift-guard against
  `apps/flutter_widgetbook/lib/widgetbook.dart`.

  Dev-only: the `/storybook` route is compile-gated on `:dev_routes`
  (see `MatomeApiWeb.Router`), so this is provably absent from a `:prod` release.
  """
  use PhoenixStorybook,
    otp_app: :matome_api,
    content_path: Path.expand("../../storybook", __DIR__),
    # Remote asset paths (not file-system paths). Reuse the admin back-office
    # bundle so components render with the real design tokens: app.css already
    # imports foundations.css + components.css + composites.css, and app.js
    # boots the LiveSocket the sandbox iframe needs.
    css_path: "/assets/app.css",
    # NOTE: no `js_path`. It would be loaded on the storybook page, and the admin
    # `app.js` boots its own `LiveSocket("/live")` — a second LiveSocket that
    # collides with phoenix_storybook's, leaving the storybook LiveView
    # disconnected (the color-mode toggle and every other push silently dies).
    # Our catalog components are static (no JS hooks), so the sandbox needs no
    # app JS; phoenix_storybook's own bundle drives the single LiveSocket.
    # The sandbox wrapper (and the component iframe <body>) carries this class.
    # `assets/css/app.css` paints it with the matome background/text tokens so
    # components render on the app's own surface — readable regardless of the
    # storybook chrome's light/dark. Default would be the dashed otp_app
    # ("matome-api"); named explicitly so the stylesheet target is obvious.
    sandbox_class: "matome-sandbox",
    # The Flutter tokens flip theme via a `.dark` class on an ancestor; the
    # storybook color-mode toggle adds exactly that class to the sandbox, so the
    # light/dark switch drives the same tokens (and the sandbox background above)
    # with no extra wiring.
    color_mode: true
end
