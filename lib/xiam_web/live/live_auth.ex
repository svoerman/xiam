defmodule XIAMWeb.LiveAuth do
  @moduledoc """
  LiveView hooks for authentication and authorization.
  """

  import Phoenix.LiveView
  import Phoenix.Component

  alias XIAM.Users
  alias XIAM.Users.User

  defp get_current_user(session) do
    with raw when not is_nil(raw) <- session["pow_user_id"],
         id when not is_nil(id) <- to_int(raw),
         %User{} = user <- Users.get_user(id) do
      user
    else
      _ -> nil
    end
  end

  defp get_admin_user(session, _socket) do
    # Get user ID from session
    user_id_str = session["pow_user_id"]

    case to_int(user_id_str) do
      id when is_integer(id) ->
        # Get user by ID
        user = Users.get_user(id)
        user
      _ ->
        # Failed to parse pow_user_id or ID was nil
        nil
    end
  end

  @doc """
  Default hook: assigns current_user from session if present.
  """
  def on_mount(:default, _params, session, socket) do
    {:cont, assign(socket, current_user: get_current_user(session))}
  end

  def on_mount(:require_authenticated, _params, session, socket) do
    current_user = get_current_user(session)

    if current_user do
      {:cont, assign(socket, current_user: current_user)}
    else
      {:halt, push_navigate(socket, to: "/session/new")}
    end
  end

  def on_mount(:require_admin, _params, session, socket) do
    case get_admin_user(session, socket) do
      %User{} = user -> {:cont, assign(socket, current_user: user)}
      _ -> {:halt, push_navigate(socket, to: "/session/new")}
    end
  end

  @doc """
  Session builder for admin LiveViews: injects pow_user_id.
  """
  def build_admin_session(conn) do
    user = Pow.Plug.current_user(conn)
    %{"pow_user_id" => user && user.id}
  end

  # Helper to convert values to integer
  defp to_int(value) when is_integer(value), do: value
  defp to_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {i, ""} -> i
      _ -> nil
    end
  end
  defp to_int(_), do: nil
end
