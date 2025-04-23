defmodule XIAMWeb.Schemas.Passkey.RegistrationRequest do
  @moduledoc """
  Schema for passkey registration request.
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  # Define the schema for the registration request
  OpenApiSpex.schema(%{
    title: "PasskeyRegistrationRequest",
    description: "Request schema for passkey registration",
    type: :object,
    properties: %{
      attestation: %Schema{
        type: :object,
        description: "WebAuthn attestation response from the client",
        properties: %{
          id: %Schema{type: :string, description: "Credential ID", format: :byte},
          rawId: %Schema{type: :string, description: "Raw credential ID", format: :byte},
          type: %Schema{type: :string, description: "Credential type", example: "public-key"},
          response: %Schema{
            type: :object,
            properties: %{
              attestationObject: %Schema{type: :string, description: "Attestation object", format: :byte},
              clientDataJSON: %Schema{type: :string, description: "Client data JSON", format: :byte}
            }
          }
        }
      },
      friendly_name: %Schema{type: :string, description: "User-friendly name for the passkey", example: "My Phone"}
    },
    required: [:attestation, :friendly_name],
    example: %{
      "attestation" => %{
        "id" => "credentialIdBase64",
        "rawId" => "credentialIdBase64",
        "type" => "public-key",
        "response" => %{
          "attestationObject" => "attestationObjectBase64",
          "clientDataJSON" => "clientDataJSONBase64"
        }
      },
      "friendly_name" => "My Phone"
    }
  })
end
