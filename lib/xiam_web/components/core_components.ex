defmodule XIAMWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  This module delegates most functionality to specialized component modules:
  - XIAMWeb.FormComponents - Form controls, inputs, buttons
  - XIAMWeb.FeedbackComponents - Modals, flash messages, feedback
  - XIAMWeb.TableComponents - Tables, lists, data display

  While directly importing the specialized modules is recommended for new code,
  this module re-exports all their functions for backward compatibility.

  Icons are provided by [heroicons](https://heroicons.com). See `icon/1` for usage.
  """
  use Phoenix.Component
  use Gettext, backend: XIAMWeb.Gettext

  alias Phoenix.LiveView.JS
  
  # Re-export components from specialized modules
  defdelegate simple_form(assigns), to: XIAMWeb.FormComponents
  defdelegate button(assigns), to: XIAMWeb.FormComponents
  defdelegate input(assigns), to: XIAMWeb.FormComponents
  
  defdelegate modal(assigns), to: XIAMWeb.FeedbackComponents
  defdelegate flash(assigns), to: XIAMWeb.FeedbackComponents
  defdelegate flash_group(assigns), to: XIAMWeb.FeedbackComponents
  defdelegate show(js \\ %JS{}, selector), to: XIAMWeb.FeedbackComponents
  defdelegate hide(js \\ %JS{}, selector), to: XIAMWeb.FeedbackComponents
  defdelegate show_modal(js \\ %JS{}, id), to: XIAMWeb.FeedbackComponents
  defdelegate hide_modal(js \\ %JS{}, id), to: XIAMWeb.FeedbackComponents
  
  defdelegate table(assigns), to: XIAMWeb.TableComponents
  defdelegate list(assigns), to: XIAMWeb.TableComponents
  defdelegate header(assigns), to: XIAMWeb.TableComponents

  # Label component
  @doc """
  Renders a label.

  ## Examples

      <.label for="email_input">Email</.label>
      <.label for="email_input" class="mb-2">Email</.label>
  """
  attr :for, :string, default: nil
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} class={["text-sm font-semibold leading-6 text-zinc-800", @class]}>
      <%= render_slot(@inner_block) %>
    </label>
    """
  end

  # Error component
  @doc """
  Renders an error message.

  ## Examples

      <.error>Invitation has expired</.error>
  """
  slot :inner_block, required: true

  def error(assigns) do
    ~H"""
    <p class="mt-3 flex gap-3 text-sm leading-6 text-rose-600">
      <.icon name="hero-exclamation-circle-mini" class="mt-0.5 h-5 w-5 flex-none text-rose-500" />
      <span><%= render_slot(@inner_block) %></span>
    </p>
    """
  end

  # Back component
  @doc """
  Renders a back navigation link.

  ## Examples

      <.back navigate={~p"/posts"}>
        Back to posts
      </.back>
  """
  attr :navigate, :any, required: true
  slot :inner_block, required: true

  def back(assigns) do
    ~H"""
    <div class="mt-16">
      <.link
        navigate={@navigate}
        class="text-sm font-semibold leading-6 text-zinc-900 hover:text-zinc-700"
      >
        <.icon name="hero-arrow-left-solid" class="h-3 w-3" />
        <%= render_slot(@inner_block) %>
      </.link>
    </div>
    """
  end

  # Icon component
  @doc """
  Renders a [Hero Icon](https://heroicons.com).

  Hero icons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from your `assets/vendor/heroicons` directory and bundled
  within your compiled app.css by the plugin in your `assets/tailwind.config.js`.

  ## Examples

      <.icon name="hero-x-mark-solid" />
      <.icon name="hero-arrow-path" class="ml-1 w-3 h-3 animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: nil

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  # Focus wrap component
  @doc """
  Renders a focus wrap container for accessibility.
  """
  attr :id, :string, required: true
  attr :rest, :global
  slot :inner_block, required: true

  def focus_wrap(assigns) do
    ~H"""
    <div
      id={@id}
      phx-hook="Phoenix.FocusWrap"
      data-focus-wrap={Jason.encode!(%{id: @id})}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </div>
    """
  end
  
  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(XIAMWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(XIAMWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
