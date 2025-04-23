defmodule XIAMWeb.Schemas.Passkey.ListPasskeysResponse do
  @moduledoc """
  Schema for listing passkeys response.
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  # Define the schema for the list passkeys response
  OpenApiSpex.schema(%{
    title: "ListPasskeysResponse",
    description: "Response schema for listing user's passkeys",
    type: :object,
    properties: %{
      success: %Schema{type: :boolean, description: "Whether the request was successful", example: true},
      passkeys: %Schema{
        type: :array,
        description: "List of user's passkeys",
        items: %Schema{
          type: :object,
          properties: %{
            id: %Schema{type: :integer, description: "Passkey ID", example: 1},
            name: %Schema{type: :string, description: "Friendly name for the passkey", example: "My Phone"},
            created_at: %Schema{type: :string, description: "When the passkey was created", format: :"date-time", example: "2025-04-20T22:00:00Z"},
            last_used: %Schema{type: :string, description: "When the passkey was last used", format: :"date-time", example: "2025-04-20T23:00:00Z", nullable: true}
          },
          required: [:id, :name, :created_at]
        }
      }
    },
    required: [:success, :passkeys],
    example: %{
      "success" => true,
      "passkeys" => [
        %{
          "id" => 1,
          "name" => "My Phone",
          "created_at" => "2025-04-20T22:00:00Z",
          "last_used" => "2025-04-20T23:00:00Z"
        },
        %{
          "id" => 2,
          "name" => "My Laptop",
          "created_at" => "2025-04-19T10:00:00Z",
          "last_used" => nil
        }
      ]
    }
  })
end
