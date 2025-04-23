defmodule XIAMWeb.Schemas.Passkey.RegistrationOptionsResponse do
  @moduledoc """
  Schema for passkey registration options response.
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  # Define the schema for the registration options response
  OpenApiSpex.schema(%{
    title: "PasskeyRegistrationOptionsResponse",
    description: "Response schema for passkey registration options",
    type: :object,
    properties: %{
      success: %Schema{type: :boolean, description: "Whether the options were generated successfully", example: true},
      options: %Schema{
        type: :object,
        description: "WebAuthn registration options",
        properties: %{
          challenge: %Schema{type: :string, description: "Base64 encoded challenge", format: :byte},
          rp: %Schema{
            type: :object,
            properties: %{
              name: %Schema{type: :string, description: "Relying party name", example: "XIAM"},
              id: %Schema{type: :string, description: "Relying party ID", example: "localhost"}
            }
          },
          user: %Schema{
            type: :object,
            properties: %{
              id: %Schema{type: :string, description: "User ID encoded as Base64", format: :byte},
              name: %Schema{type: :string, description: "User's username or email", example: "user@example.com"},
              displayName: %Schema{type: :string, description: "User's display name", example: "John Doe"}
            }
          },
          pubKeyCredParams: %Schema{
            type: :array,
            description: "Public key credential parameters",
            items: %Schema{
              type: :object,
              properties: %{
                type: %Schema{type: :string, description: "Credential type", example: "public-key"},
                alg: %Schema{type: :integer, description: "Algorithm identifier", example: -7}
              }
            }
          },
          timeout: %Schema{type: :integer, description: "Timeout in milliseconds", example: 60000},
          attestation: %Schema{type: :string, description: "Attestation conveyance preference", example: "none"},
          authenticatorSelection: %Schema{
            type: :object,
            properties: %{
              authenticatorAttachment: %Schema{type: :string, description: "Authenticator attachment", example: "platform", nullable: true},
              userVerification: %Schema{type: :string, description: "User verification requirement", example: "preferred"}
            }
          }
        }
      }
    },
    required: [:success, :options],
    example: %{
      "success" => true,
      "options" => %{
        "challenge" => "randombase64string",
        "rp" => %{
          "name" => "XIAM",
          "id" => "localhost"
        },
        "user" => %{
          "id" => "userIdBase64",
          "name" => "user@example.com",
          "displayName" => "John Doe"
        },
        "pubKeyCredParams" => [
          %{
            "type" => "public-key",
            "alg" => -7
          }
        ],
        "timeout" => 60000,
        "attestation" => "none",
        "authenticatorSelection" => %{
          "authenticatorAttachment" => "platform",
          "userVerification" => "preferred"
        }
      }
    }
  })
end
