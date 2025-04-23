defmodule XIAMWeb.Schemas.Passkey.AuthenticationRequest do
  @moduledoc """
  Schema for passkey authentication request.
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  # Define the schema for the authentication request
  OpenApiSpex.schema(%{
    title: "PasskeyAuthenticationRequest",
    description: "Request schema for passkey authentication",
    type: :object,
    properties: %{
      assertion: %Schema{
        type: :object,
        description: "WebAuthn assertion response from the client",
        properties: %{
          id: %Schema{type: :string, description: "Credential ID", format: :byte},
          rawId: %Schema{type: :string, description: "Raw credential ID", format: :byte},
          type: %Schema{type: :string, description: "Credential type", example: "public-key"},
          response: %Schema{
            type: :object,
            properties: %{
              authenticatorData: %Schema{type: :string, description: "Authenticator data", format: :byte},
              clientDataJSON: %Schema{type: :string, description: "Client data JSON", format: :byte},
              signature: %Schema{type: :string, description: "Signature", format: :byte},
              userHandle: %Schema{type: :string, description: "User handle (optional)", format: :byte, nullable: true}
            }
          }
        }
      }
    },
    required: [:assertion],
    example: %{
      "assertion" => %{
        "id" => "credentialIdBase64",
        "rawId" => "credentialIdBase64",
        "type" => "public-key",
        "response" => %{
          "authenticatorData" => "authenticatorDataBase64",
          "clientDataJSON" => "clientDataJSONBase64",
          "signature" => "signatureBase64",
          "userHandle" => nil
        }
      }
    }
  })
end
