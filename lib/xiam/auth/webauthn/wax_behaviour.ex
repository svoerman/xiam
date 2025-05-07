defmodule XIAM.Auth.WebAuthn.WaxBehaviour do
  @moduledoc """
  Behaviour module defining the interface for the Wax WebAuthn library.
  This is used primarily for mocking in tests.
  """

  @doc """
  Verifies a WebAuthn authentication assertion.
  
  ## Parameters
  - authenticator_data: binary authenticator data
  - client_data_json: client data JSON
  - signature: signature from authenticator
  - public_key: public key in map format
  - challenge: Wax.Challenge struct
  - opts: Additional options like previous_sign_count and user_handle
  """
  @callback authenticate(
    authenticator_data :: binary(),
    client_data_json :: binary(),
    signature :: binary(),
    public_key :: map(),
    challenge :: Wax.Challenge.t(),
    opts :: Keyword.t()
  ) :: {:ok, map()} | {:error, any()}
end
