defmodule Wax.Behaviour do
  @callback register(attestation_object :: any, client_data_json :: any, challenge :: any) ::
              {:ok, {any, any}} | {:error, any}

  @callback authenticate(
    challenge :: any,
    credential_id :: any,
    authenticator_data :: any,
    signature :: any,
    client_data_json :: any
  ) :: {:ok, any} | {:error, any}
end
