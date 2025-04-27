defmodule XIAM.Auth.WebAuthn do
  @moduledoc """
  Acts as a facade for WebAuthn (passkey) operations.
  Delegates registration and authentication tasks to specific submodules.
  """
  alias XIAM.Users.User
  alias XIAM.Auth.WebAuthn.{Registration, Authentication}
  require Logger

  # Configuration - fetched from application env
  # Ensure these are set in config/config.exs
  # config :xiam, :webauthn,
  #   rp_id: "your_relying_party_id",
  #   rp_origin: "your_relying_party_origin", # e.g., "https://example.com"
  #   rp_name: "Your Application Name"

  @doc """
  Generates registration options for creating a new passkey.
  Delegates to `XIAM.Auth.WebAuthn.Registration`.
  """
  def generate_registration_options(%User{} = user) do
    Logger.debug("Delegating registration option generation to Registration module.")
    Registration.generate_registration_options(user)
  end

  @doc """
  Verifies a registration attestation and creates a new passkey.
  Delegates to `XIAM.Auth.WebAuthn.Registration`.
  """
  def verify_registration(%User{} = user, attestation, challenge, friendly_name) do
    Logger.debug("Delegating registration verification to Registration module.")
    Registration.verify_registration(user, attestation, challenge, friendly_name)
  end

  @doc """
  Generates authentication options (challenge) for verifying a passkey.
  Delegates to `XIAM.Auth.WebAuthn.Authentication`.
  """
  def generate_authentication_options(email \\ nil) do
    Logger.debug("Delegating authentication option generation to Authentication module. Email hint: #{inspect(email)}")
    Authentication.generate_authentication_options(email)
  end

  @doc """
  Verifies an authentication assertion.
  Delegates to `XIAM.Auth.WebAuthn.Authentication`.
  """
  def verify_authentication(assertion, challenge) do
    Logger.debug("Delegating authentication verification to Authentication module.")
    Authentication.verify_authentication(assertion, challenge)
  end
end
