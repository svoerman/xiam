defmodule XIAM.Auth.WebAuthn.HelpersBehaviour do
  @moduledoc """
  Behaviour module defining the interface for WebAuthn helpers.
  This is used primarily for mocking in tests.
  """

  @doc """
  Decodes a CBOR-encoded public key into a map format.
  
  ## Parameters
  - public_key_cbor: The CBOR-encoded public key binary
  
  ## Returns
  - Map representation of the public key
  """
  @callback decode_public_key(public_key_cbor :: binary()) :: map()
end
