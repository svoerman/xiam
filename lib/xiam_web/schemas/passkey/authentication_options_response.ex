defmodule XIAMWeb.Schemas.Passkey.AuthenticationOptionsResponse do
  @moduledoc """
  Schema for passkey authentication options response.
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  # Define the schema for the authentication options response
  OpenApiSpex.schema(%{
    title: "PasskeyAuthenticationOptionsResponse",
    description: "Response schema for passkey authentication options",
    type: :object,
    properties: %{
      challenge: %Schema{type: :string, description: "Base64 encoded challenge", format: :byte},
      timeout: %Schema{type: :integer, description: "Timeout for the authentication in milliseconds", example: 60000},
      rpId: %Schema{type: :string, description: "Relying party ID", example: "localhost"},
      userVerification: %Schema{type: :string, description: "User verification requirement", example: "preferred", enum: ["required", "preferred", "discouraged"]},
      allowCredentials: %Schema{
        type: :array,
        description: "List of allowed credentials",
        items: %Schema{
          type: :object,
          properties: %{
            id: %Schema{type: :string, description: "Credential ID", format: :byte},
            type: %Schema{type: :string, description: "Credential type", example: "public-key"}
          }
        }
      }
    },
    required: [:challenge, :rpId],
    example: %{
      "challenge" => "randombase64string",
      "timeout" => 60000,
      "rpId" => "localhost",
      "userVerification" => "preferred",
      "allowCredentials" => [
        %{
          "id" => "credentialIdBase64",
          "type" => "public-key"
        }
      ]
    }
  })
end
