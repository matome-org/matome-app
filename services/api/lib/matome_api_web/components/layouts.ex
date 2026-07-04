defmodule MatomeApiWeb.Layouts do
  @moduledoc """
  Root + app layouts for the /admin back-office (W0 #1868).

  The layouts pull in the compiled asset bundle (`/assets/app.css`,
  `/assets/app.js`). The CSS carries the foundations design tokens extracted
  from the Flutter app (`assets/css/foundations.css`), so the admin shell
  renders on the same palette/type scale as the mobile client.
  """
  use MatomeApiWeb, :html

  embed_templates "layouts/*"
end
