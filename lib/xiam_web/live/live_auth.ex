defmodule XIAMWeb.LiveAuth do
  @moduledoc """
  LiveView hooks for authentication and authorization.
  """

  import Phoenix.LiveView
  import Phoenix.Component

  alias XIAM.Users.User
  alias XIAM.Repo

  defp get_current_user(session) do
    with raw when not is_nil(raw) <- session["pow_user_id"],
         id when not is_nil(id) <- to_int(raw),
         %User{} = user <- Repo.get(User, id) do
      user
    else
      _ -> nil
    end
  end

  defp get_admin_user(session, _socket) do
    case to_int(session["pow_user_id"]) do
      id when is_integer(id) ->
        case Repo.get(User, id) do
          nil -> nil
          user -> Repo.preload(user, role: :capabilities)
        end
      _ -> nil
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
      # Store path, redirect, and halt
      socket = 
        socket
        |> Phoenix.LiveView.put_session("request_path", socket.request_path)
        |> Phoenix.LiveView.redirect(to: "/session/new")

      {:halt, socket}
    end
  end

  def on_mount(:require_admin, _params, session, socket) do
    {:cont, assign(socket, current_user: get_admin_user(session, socket))}
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
