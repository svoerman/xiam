defmodule XIAM.Users.Behaviour do
  @callback list_user_passkeys(any()) :: list()
  @callback update_user_passkey_settings(any(), map()) :: {:ok, any()} | {:error, any()}
  @callback delete_user_passkey(any(), any()) :: {:ok, any()} | {:error, any()}
end
