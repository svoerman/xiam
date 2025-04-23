defmodule XIAMWeb.Schemas.Passkey.RegistrationResponse do
  @moduledoc """
  Schema for passkey registration response.
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  # Define the schema for the registration response
  OpenApiSpex.schema(%{
    title: "PasskeyRegistrationResponse",
    description: "Response schema for successful passkey registration",
    type: :object,
    properties: %{
      success: %Schema{type: :boolean, description: "Whether the registration was successful", example: true},
      passkey: %Schema{
        type: :object,
        description: "Information about the registered passkey",
        properties: %{
          id: %Schema{type: :integer, description: "Passkey ID in the database", example: 1},
          name: %Schema{type: :string, description: "Friendly name of the passkey", example: "My Phone"},
          created_at: %Schema{type: :string, description: "When the passkey was created", format: :"date-time"}
        }
      }
    },
    required: [:success, :passkey],
    example: %{
      "success" => true,
      "passkey" => %{
        "id" => 1,
        "name" => "My Phone",
        "created_at" => "2025-04-20T22:00:00Z"
      }
    }
  })
end

# Define the schema for registration error response as a separate module
defmodule XIAMWeb.Schemas.Passkey.RegistrationErrorResponse do
  @moduledoc """
  Schema for passkey registration error response.
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema
  
  OpenApiSpex.schema(%{
    title: "PasskeyRegistrationErrorResponse",
    description: "Response schema for failed passkey registration",
    type: :object,
    properties: %{
      success: %Schema{type: :boolean, description: "Whether the registration was successful", example: false},
      error: %Schema{type: :string, description: "Error message", example: "Invalid attestation"}
    },
    required: [:success, :error],
    example: %{
      "success" => false,
      "error" => "Invalid attestation"
    }
  })
end
