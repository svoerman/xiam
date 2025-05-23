defmodule XIAMWeb.Layouts do
  use Phoenix.Component
  import XIAMWeb.HeaderComponent, only: [main_header: 1]

  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is set as the default
  layout on both `use XIAMWeb, :controller` and
  `use XIAMWeb, :live_view`.
  """
  use XIAMWeb, :html

  embed_templates "layouts/*"
end
