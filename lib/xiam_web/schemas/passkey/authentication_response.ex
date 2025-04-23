defmodule XIAMWeb.Schemas.Passkey.AuthenticationResponse do
  @moduledoc """
  Schema for passkey authentication response.
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  # Define the schema for the authentication response
  OpenApiSpex.schema(%{
    title: "PasskeyAuthenticationResponse",
    description: "Response schema for successful passkey authentication",
    type: :object,
    properties: %{
      success: %Schema{type: :boolean, description: "Whether the authentication was successful", example: true},
      token: %Schema{type: :string, description: "JWT token for API access", format: :jwt},
      redirect_to: %Schema{type: :string, description: "URL to redirect to for completing web session authentication", format: :uri},
      user: %Schema{
        type: :object,
        description: "Basic user information",
        properties: %{
          id: %Schema{type: :integer, description: "User ID", example: 1},
          email: %Schema{type: :string, description: "User email", format: :email, example: "user@example.com"},
          admin: %Schema{type: :boolean, description: "Whether the user is an admin", example: false},
          name: %Schema{type: :string, description: "User's display name", example: "John Doe", nullable: true}
        }
      }
    },
    required: [:success, :token, :redirect_to, :user],
    example: %{
      "success" => true,
      "token" => "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
      "redirect_to" => "/auth/passkey/complete?auth_token=user_id:timestamp:hmac",
      "user" => %{
        "id" => 1,
        "email" => "user@example.com",
        "admin" => false,
        "name" => "John Doe"
      }
    }
  })
end

defmodule XIAMWeb.Schemas.Passkey.AuthenticationErrorResponse do
  @moduledoc """
  Schema for passkey authentication error response.
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  # Define the schema for authentication error response
  OpenApiSpex.schema(%{
    title: "PasskeyAuthenticationErrorResponse",
    description: "Response schema for failed passkey authentication",
    type: :object,
    properties: %{
      success: %Schema{type: :boolean, description: "Whether the authentication was successful", example: false},
      error: %Schema{type: :string, description: "Error message", example: "Invalid signature"}
    },
    required: [:success, :error],
    example: %{
      "success" => false,
      "error" => "Invalid signature"
    }
  })
end
