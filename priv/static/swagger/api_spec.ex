defmodule XIAMWeb.ApiSpec do
  @moduledoc """
  Provides the OpenAPI specification for the XIAM API.
  """
  use OpenApiSpex.Server, otp_app: :xiam

  alias OpenApiSpex.{Info, OpenApi, Operation, PathItem, Response, MediaType, RequestBody, SecurityScheme, Schema, Parameter}
  alias XIAMWeb.Router

  def spec do
    %OpenApi{
      openapi: "3.0.0",
      info: %Info{
        title: "XIAM API",
        version: Application.spec(:xiam, :vsn) |> to_string(),
        description: "API for XIAM user authentication and management."
      },
      servers: [
        %Server{url: "http://localhost:4000", description: "Development server"}
      ],
      components: %{
        securitySchemes: %{
          "jwt" => %SecurityScheme{type: "http", scheme: "bearer", bearerFormat: "JWT", description: "JWT authentication token. Prefix with 'Bearer '."},
          # Session cookie name might differ based on Plug.Session options
          "session" => %SecurityScheme{type: "apiKey", name: "_xiam_key", in: "cookie", description: "Session cookie authentication (used for passkey management)"},
          "partialJwt" => %SecurityScheme{type: "http", scheme: "bearer", bearerFormat: "JWT", description: "Partial JWT token issued during MFA flow. Prefix with 'Bearer '."} # Specific for MFA
        },
        schemas: %{
          # === Generic Schemas ===
          "ErrorResponse" => %Schema{
            type: :object,
            properties: %{
              success: %Schema{type: :boolean, example: false},
              error: %Schema{type: :string},
              details: %Schema{type: :object, description: "Validation errors", nullable: true}
            },
            required: [:success, :error]
          },
          "SuccessMessageResponse" => %Schema{
            type: :object,
            properties: %{
              success: %Schema{type: :boolean, example: true},
              message: %Schema{type: :string}
            },
            required: [:success, :message]
          },
          "PaginationMeta" => %Schema{
            type: :object,
            properties: %{
              page: %Schema{type: :integer},
              per_page: %Schema{type: :integer},
              total: %Schema{type: :integer},
              total_pages: %Schema{type: :integer}
            }
          },

          # === Health/System Schemas ===
          "HealthResponse" => %Schema{
            type: :object,
            properties: %{
              status: %Schema{type: :string, example: "ok"},
              version: %Schema{type: :string, example: "0.1.0"},
              environment: %Schema{type: :string, example: "dev"},
              timestamp: %Schema{type: :string, format: :"date-time"}
            }
          },
          "DetailedStatusResponse" => %Schema{
            type: :object,
            description: "Detailed system status",
            properties: %{
              # Reflects XIAM.System.Health.check_health/0 structure
              db_status: %Schema{type: :string, example: "ok"},
              memory: %Schema{
                type: :object,
                properties: %{
                  total: %Schema{type: :number, format: :float, description: "Total memory in MB"},
                  allocated: %Schema{type: :number, format: :float, description: "Allocated memory in MB"},
                  atom: %Schema{type: :number, format: :float, description: "Atom memory in MB"},
                  binary: %Schema{type: :number, format: :float, description: "Binary memory in MB"},
                  code: %Schema{type: :number, format: :float, description: "Code memory in MB"},
                  ets: %Schema{type: :number, format: :float, description: "ETS memory in MB"},
                  processes: %Schema{type: :number, format: :float, description: "Processes memory in MB"}
                }
              },
              version: %Schema{type: :string, example: "0.1.0"},
              environment: %Schema{type: :string, example: "dev"},
              timestamp: %Schema{type: :string, format: :"date-time"}
            }
          },

          # === Auth Schemas ===
          "LoginRequest" => %Schema{
            type: :object,
            properties: %{
              email: %Schema{type: :string, format: :email},
              password: %Schema{type: :string, format: :password}
            },
            required: [:email, :password]
          },
          "LoginUserResponse" => %Schema{
            type: :object,
            description: "Basic user information returned on login/verify",
            properties: %{
              id: %Schema{type: :integer},
              email: %Schema{type: :string},
              mfa_enabled: %Schema{type: :boolean},
              role: %Schema{
                type: :object,
                nullable: true,
                properties: %{
                  id: %Schema{type: :integer},
                  name: %Schema{type: :string},
                  capabilities: %Schema{type: :array, items: %Schema{type: :string}}
                }
              }
            }
          },
          "LoginSuccessResponse" => %Schema{
            type: :object,
            properties: %{
              success: %Schema{type: :boolean, example: true},
              mfa_required: %Schema{type: :boolean, example: false, nullable: true, description: "Indicates if MFA verification step is required"},
              partial_token: %Schema{type: :string, description: "Partial JWT token issued if mfa_required is true", nullable: true},
              token: %Schema{type: :string, description: "Full JWT token if login is complete (no MFA or MFA verified)", nullable: true},
              user: Schema.ref("#/components/schemas/LoginUserResponse")
            },
            required: [:success]
          },
          "TokenResponse" => %Schema{
            type: :object,
            properties: %{
              success: %Schema{type: :boolean, example: true},
              token: %Schema{type: :string, description: "JWT token"}
            },
            required: [:success, :token]
          },
          "VerifyResponse" => %Schema{
            type: :object,
            properties: %{
              success: %Schema{type: :boolean, example: true},
              valid: %Schema{type: :boolean, example: true},
              user: Schema.ref("#/components/schemas/LoginUserResponse")
            },
            required: [:success, :valid, :user]
          },
          "LogoutResponse" => %Schema{
            type: :object,
            properties: %{
              success: %Schema{type: :boolean, example: true},
              message: %Schema{type: :string, example: "Logged out successfully"}
            },
            required: [:success, :message]
          },
          "MfaChallengeResponse" => %Schema{
            type: :object,
            properties: %{
              success: %Schema{type: :boolean, example: true},
              message: %Schema{type: :string, example: "Please enter the code from your authenticator app"}
            },
            required: [:success, :message]
          },
          "MfaVerifyRequest" => %Schema{
            type: :object,
            properties: %{
              code: %Schema{type: :string, description: "The TOTP code from the authenticator app"}
            },
            required: [:code]
          },

          # === User Schemas ===
          "UserBase" => %Schema{ # Base schema for user data in responses
            type: :object,
            properties: %{
              id: %Schema{type: :integer},
              email: %Schema{type: :string},
              mfa_enabled: %Schema{type: :boolean},
              role: %Schema{
                type: :object,
                nullable: true,
                properties: %{
                  id: %Schema{type: :integer},
                  name: %Schema{type: :string}
                }
              },
              inserted_at: %Schema{type: :string, format: :"date-time"},
              updated_at: %Schema{type: :string, format: :"date-time"}
            }
          },
          "UserListResponse" => %Schema{
            type: :object,
            properties: %{
              success: %Schema{type: :boolean, example: true},
              data: %Schema{type: :array, items: Schema.ref("#/components/schemas/UserBase")},
              meta: Schema.ref("#/components/schemas/PaginationMeta")
            }
          },
          "UserDetailResponse" => %Schema{
            type: :object,
            properties: %{
              success: %Schema{type: :boolean, example: true},
              data: Schema.ref("#/components/schemas/UserBase")
            }
          },
          "CreateUserRequest" => %Schema{
            type: :object,
            properties: %{
              user: %Schema{
                type: :object,
                properties: %{
                  email: %Schema{type: :string, format: :email},
                  password: %Schema{type: :string, format: :password},
                  role_id: %Schema{type: :integer, nullable: true, description: "ID of the role to assign"}
                },
                required: [:email, :password]
              }
            },
            required: [:user]
          },
          "CreateUserResponse" => %Schema{
            type: :object,
            properties: %{
              success: %Schema{type: :boolean, example: true},
              message: %Schema{type: :string, example: "User created successfully"},
              data: %Schema{
                type: :object,
                properties: %{
                  id: %Schema{type: :integer},
                  email: %Schema{type: :string}
                }
              }
            },
            required: [:success, :message, :data]
          },
          "UpdateUserRequest" => %Schema{
            type: :object,
            properties: %{
              user: %Schema{
                type: :object,
                description: "Include fields to update (e.g., email, password, role_id). At least one field is required.",
                properties: %{
                  email: %Schema{type: :string, format: :email, nullable: true},
                  password: %Schema{type: :string, format: :password, nullable: true, description: "Provide new password to update"},
                  role_id: %Schema{type: :integer, nullable: true}
                }
              }
            },
            required: [:user]
          },
          "UpdateUserResponse" => %Schema{
            type: :object,
            properties: %{
              success: %Schema{type: :boolean, example: true},
              message: %Schema{type: :string, example: "User updated successfully"},
              data: %Schema{
                type: :object,
                properties: %{
                  id: %Schema{type: :integer},
                  email: %Schema{type: :string}
                }
              }
            },
            required: [:success, :message, :data]
          },
          "DeleteUserResponse" => %Schema{
            type: :object,
            properties: %{
              success: %Schema{type: :boolean, example: true},
              message: %Schema{type: :string, example: "User deleted successfully"}
            },
            required: [:success, :message]
          },

          # === Consent Schemas ===
          "ConsentRecordResponse" => %Schema{
            type: :object,
            properties: %{
              id: %Schema{type: :integer},
              user_id: %Schema{type: :integer},
              consent_type: %Schema{type: :string},
              consent_given: %Schema{type: :boolean},
              recorded_at: %Schema{type: :string, format: :"date-time"},
              expires_at: %Schema{type: :string, format: :"date-time", nullable: true},
              source: %Schema{type: :string, nullable: true},
              metadata: %Schema{type: :object, nullable: true, description: "Metadata captured during consent recording"}
            }
          },
          "ConsentListResponse" => %Schema{
            type: :object,
            properties: %{
              data: %Schema{type: :array, items: Schema.ref("#/components/schemas/ConsentRecordResponse")},
              page_info: Schema.ref("#/components/schemas/PaginationMeta") # Matches render call
            }
          },
          "CreateConsentRequest" => %Schema{
            type: :object,
            description: "Fields needed to create a consent record. 'user_id' is optional (defaults to current user, requires admin to set for others).",
            properties: %{
              user_id: %Schema{type: :integer, nullable: true},
              consent_type: %Schema{type: :string},
              consent_given: %Schema{type: :boolean}
              # Potentially 'source' and 'metadata' if allowed during creation?
            },
            required: [:consent_type, :consent_given]
          },
          "UpdateConsentRequest" => %Schema{
            type: :object,
            description: "Fields to update a consent record.",
            properties: %{
              consent_given: %Schema{type: :boolean}
              # Potentially 'expires_at'? Source/metadata likely shouldn't be updated.
            },
            required: [:consent_given]
          },

          # === Access Control Schemas ===
          "AccessRecordResponse" => %Schema{
            type: :object,
            properties: %{
              id: %Schema{type: :integer},
              user_id: %Schema{type: :integer},
              entity_type: %Schema{type: :string},
              entity_id: %Schema{type: :string},
              role_id: %Schema{type: :integer}
            }
          },
          "AccessListResponse" => %Schema{
            type: :object,
            properties: %{
              data: %Schema{type: :array, items: Schema.ref("#/components/schemas/AccessRecordResponse")}
            }
          },
          "SetUserAccessRequest" => %Schema{
            type: :object,
            properties: %{
              user_id: %Schema{type: :integer},
              entity_type: %Schema{type: :string, description: "e.g., 'product', 'account'"},
              entity_id: %Schema{type: :string},
              role: %Schema{type: :string, description: "Name of the role to assign"}
            },
            required: [:user_id, :entity_type, :entity_id, :role]
          },
          "CapabilityResponse" => %Schema{
            type: :object,
            properties: %{
              id: %Schema{type: :integer},
              product_id: %Schema{type: :integer},
              name: %Schema{type: :string},
              description: %Schema{type: :string, nullable: true}
            }
          },
          "CapabilityListResponse" => %Schema{
             type: :object,
             properties: %{
               data: %Schema{type: :array, items: Schema.ref("#/components/schemas/CapabilityResponse")}
             }
           },
          "CreateCapabilityRequest" => %Schema{
            type: :object,
            properties: %{
              product_id: %Schema{type: :integer},
              capability_name: %Schema{type: :string},
              description: %Schema{type: :string, nullable: true}
            },
            required: [:product_id, :capability_name]
          },

          # === Product Schemas ===
          "ProductResponse" => %Schema{
            type: :object,
            properties: %{
              id: %Schema{type: :integer},
              product_name: %Schema{type: :string}
              # Reflects AccessControl.create_product return
            }
          },
          "ProductListResponse" => %Schema{
             type: :object,
             properties: %{
               data: %Schema{type: :array, items: Schema.ref("#/components/schemas/ProductResponse")}
             }
          },
          "CreateProductRequest" => %Schema{
            type: :object,
            properties: %{
              product_name: %Schema{type: :string}
            },
            required: [:product_name]
          },

          # === Passkey Schemas ===
          "RegistrationOptionsResponse" => %Schema{
             type: :object,
             properties: %{
               success: %Schema{type: :boolean, example: true},
               options: %Schema{
                 type: :object,
                 description: "WebAuthn PublicKeyCredentialCreationOptions",
                 properties: %{
                   challenge: %Schema{type: :string, description: "Base64URL encoded challenge"},
                   rp: %Schema{type: :object, properties: %{id: %Schema{type: :string}, name: %Schema{type: :string}}},
                   user: %Schema{type: :object, properties: %{id: %Schema{type: :string}, name: %Schema{type: :string}, displayName: %Schema{type: :string}}},
                   pubKeyCredParams: %Schema{type: :array, items: %Schema{type: :object, properties: %{alg: %Schema{type: :integer}, type: %Schema{type: :string}}}},
                   timeout: %Schema{type: :integer},
                   attestation: %Schema{type: :string},
                   authenticatorSelection: %Schema{type: :object, properties: %{authenticatorAttachment: %Schema{type: :string, nullable: true}, requireResidentKey: %Schema{type: :boolean}, residentKey: %Schema{type: :string}, userVerification: %Schema{type: :string}}}
                   # Potentially add 'extensions' if used
                 }
               }
             },
             required: [:success, :options]
           },
          "RegistrationRequest" => %Schema{
             type: :object,
             properties: %{
               friendly_name: %Schema{type: :string, description: "A user-friendly name for the passkey"},
               attestation: %Schema{
                 type: :object,
                 description: "WebAuthn Attestation response object (PublicKeyCredential)",
                 properties: %{
                   id: %Schema{type: :string}, # Credential ID (Base64URL)
                   rawId: %Schema{type: :string}, # Raw Credential ID (Base64URL)
                   type: %Schema{type: :string, example: "public-key"},
                   response: %Schema{
                     type: :object,
                     properties: %{
                       attestationObject: %Schema{type: :string, description: "Base64URL encoded attestation object"},
                       clientDataJSON: %Schema{type: :string, description: "Base64URL encoded client data JSON"}
                       # transports might be included here too
                     }
                   }
                   # clientExtensionResults might be included
                 }
               }
             },
             required: [:friendly_name, :attestation]
           },
          "RegistrationResponse" => %Schema{
             type: :object,
             properties: %{
               success: %Schema{type: :boolean, example: true},
               message: %Schema{type: :string, example: "Passkey registered successfully"}
             },
             required: [:success, :message]
           },
          "RegistrationErrorResponse" => %Schema{
            type: :object,
            properties: %{
              success: %Schema{type: :boolean, example: false},
              error: %Schema{type: :string, description: "Reason for registration failure"}
            },
            required: [:success, :error]
          },
          "AuthenticationOptionsResponse" => %Schema{
            type: :object,
            description: "WebAuthn PublicKeyCredentialRequestOptions",
            # Note: This schema structure comes directly from the webauthn library's output
            properties: %{
              challenge: %Schema{type: :string, description: "Base64URL encoded challenge"},
              timeout: %Schema{type: :integer},
              rpId: %Schema{type: :string},
              allowCredentials: %Schema{
                type: :array,
                items: %Schema{
                  type: :object,
                  properties: %{
                    id: %Schema{type: :string, description: "Base64URL encoded credential ID"},
                    type: %Schema{type: :string, example: "public-key"},
                    transports: %Schema{type: :array, items: %Schema{type: :string}, nullable: true}
                  }
                }
              },
              userVerification: %Schema{type: :string}
            }
          },
          "AuthenticationRequest" => %Schema{
            type: :object,
            properties: %{
              assertion: %Schema{
                type: :object,
                description: "WebAuthn Assertion response object (PublicKeyCredential)",
                properties: %{
                  id: %Schema{type: :string}, # Credential ID (Base64URL)
                  rawId: %Schema{type: :string}, # Raw Credential ID (Base64URL)
                  type: %Schema{type: :string, example: "public-key"},
                  response: %Schema{
                    type: :object,
                    properties: %{
                      authenticatorData: %Schema{type: :string, description: "Base64URL encoded authenticator data"},
                      clientDataJSON: %Schema{type: :string, description: "Base64URL encoded client data JSON"},
                      signature: %Schema{type: :string, description: "Base64URL encoded signature"},
                      userHandle: %Schema{type: :string, nullable: true, description: "Base64URL encoded user handle (if available)"}
                    }
                  }
                  # clientExtensionResults might be included
                }
              }
            },
            required: [:assertion]
          },
          "AuthenticationResponse" => %Schema{
            type: :object,
            properties: %{
              success: %Schema{type: :boolean, example: true},
              token: %Schema{type: :string, description: "JWT token for API access"},
              redirect_to: %Schema{type: :string, description: "URL to redirect to for web session auth (contains secure token)"},
              user: Schema.ref("#/components/schemas/LoginUserResponse") # Reusing this schema
            },
            required: [:success, :token, :redirect_to, :user]
          },
          "AuthenticationErrorResponse" => %Schema{
            type: :object,
            properties: %{
              success: %Schema{type: :boolean, example: false},
              error: %Schema{type: :string, description: "Reason for authentication failure"}
            },
            required: [:success, :error]
          },
          "PasskeyListItem" => %Schema{
             type: :object,
             properties: %{
               id: %Schema{type: :integer},
               friendly_name: %Schema{type: :string},
               last_used_at: %Schema{type: :string, format: :"date-time", nullable: true},
               created_at: %Schema{type: :string, format: :"date-time"}
             }
           },
          "ListPasskeysResponse" => %Schema{
             type: :object,
             properties: %{
               success: %Schema{type: :boolean, example: true},
               passkeys: %Schema{type: :array, items: Schema.ref("#/components/schemas/PasskeyListItem")}
             },
             required: [:success, :passkeys]
           }
        }
      },
      paths: %{
        # === Health Endpoint ===
        "/health" => %{
          get: %Operation{
            tags: ["System"],
            summary: "System health check",
            description: "Public endpoint for basic system health status.",
            operationId: "XIAMWeb.API.SystemController.health",
            responses: %{
              200 => %Response{
                description: "OK",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/HealthResponse")}}
              }
            }
          }
        },
        "/system/status" => %{ # Changed from /api/system/status to match controller
          get: %Operation{
            tags: ["System"],
            summary: "Detailed system status",
            description: "Retrieves detailed status of various system components (requires admin).",
            operationId: "XIAMWeb.API.SystemController.status",
            security: [%{"jwt" => []}],
            responses: %{
              200 => %Response{
                description: "Detailed System Status",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/DetailedStatusResponse")}}
              },
              401 => %Response{
                description: "Unauthorized",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/ErrorResponse")}}
              },
              403 => %Response{ # Added based on controller admin check
                description: "Forbidden (Admin access required)",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/ErrorResponse")}}
              }
            }
          }
        },

        # === Passkey Authentication Endpoints (Public) ===
        "/passkeys/authentication/options" => %{
          get: %Operation{
            tags: ["Passkeys"],
            summary: "Generate passkey authentication options",
            description: "Generates WebAuthn authentication options for passkey login. Supports usernameless flow.",
            operationId: "XIAMWeb.API.PasskeyController.authentication_options",
            parameters: [
              %Parameter{name: "email", in: :query, description: "Optional user email hint", required: false, schema: %Schema{type: :string}}
            ],
            responses: %{
              200 => %Response{
                description: "Authentication options",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/AuthenticationOptionsResponse")}}
              }
              # Add 400/500 error responses if applicable from controller
            }
          }
        },
        "/passkeys/authentication" => %{
          post: %Operation{
            tags: ["Passkeys"],
            summary: "Authenticate with a passkey",
            description: "Authenticates a user via WebAuthn assertion. Supports usernameless flow.",
            operationId: "XIAMWeb.API.PasskeyController.authenticate",
            requestBody: %RequestBody{
              description: "WebAuthn Assertion Response",
              required: true,
              content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/AuthenticationRequest")}}
            },
            responses: %{
              200 => %Response{
                description: "Authentication successful",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/AuthenticationResponse")}}
              },
              400 => %Response{ # Added based on controller logic (missing challenge)
                description: "Bad Request (e.g., session expired)",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/AuthenticationErrorResponse")}}
              },
              401 => %Response{
                description: "Authentication failed (e.g., invalid assertion)",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/AuthenticationErrorResponse")}}
              }
              # Add 500 error responses if applicable from controller
            }
          }
        },

        # === Auth Endpoints (Standard JWT) ===
        "/auth/login" => %{
          post: %Operation{
            tags: ["Auth"],
            summary: "Login with email and password",
            description: "Authenticates a user with email/password, returns JWT token (possibly partial if MFA needed).",
            operationId: "XIAMWeb.API.AuthController.login",
            requestBody: %RequestBody{
              required: true,
              content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/LoginRequest")}}
            },
            responses: %{
              200 => %Response{
                description: "Login successful (may require MFA verification)",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/LoginSuccessResponse")}}
              },
              401 => %Response{
                description: "Invalid credentials",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/ErrorResponse")}}
              }
              # Add 500 error responses if applicable from controller
            }
          }
        },
        "/auth/refresh" => %{
          post: %Operation{
            tags: ["Auth"],
            summary: "Refresh JWT token",
            description: "Exchanges a valid JWT token for a new JWT token.",
            operationId: "XIAMWeb.API.AuthController.refresh_token",
            security: [%{"jwt" => []}], # Requires a valid (non-partial) JWT
            responses: %{
              200 => %Response{
                description: "Token refreshed successfully",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/TokenResponse")}}
              },
              401 => %Response{
                description: "Invalid or expired token",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/ErrorResponse")}}
              }
              # Add 500 error responses if applicable from controller
            }
          }
        },
        "/auth/verify" => %{
          get: %Operation{
            tags: ["Auth"],
            summary: "Verify JWT token validity",
            description: "Checks if the provided JWT token is valid and returns user info.",
            operationId: "XIAMWeb.API.AuthController.verify_token",
            security: [%{"jwt" => []}], # Requires a valid (non-partial) JWT
            responses: %{
              200 => %Response{
                description: "Token is valid",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/VerifyResponse")}}
              },
              401 => %Response{
                description: "Invalid or expired token",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/ErrorResponse")}}
              }
              # Add 500 error responses if applicable from controller
            }
          }
        },
        "/auth/logout" => %{
          post: %Operation{
            tags: ["Auth"],
            summary: "Logout API session",
            description: "Logs API logout action (JWTs are stateless, client should clear token).",
            operationId: "XIAMWeb.API.AuthController.logout",
            security: [%{"jwt" => []}], # Requires a valid (non-partial) JWT
            responses: %{
              200 => %Response{
                description: "Logout successful",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/LogoutResponse")}}
              },
              401 => %Response{
                description: "Unauthorized",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/ErrorResponse")}}
              }
              # Add 500 error responses if applicable from controller
            }
          }
        },
        "/auth/mfa/challenge" => %{
          get: %Operation{
            tags: ["Auth"],
            summary: "Get MFA challenge information",
            description: "Indicates that MFA verification is required. Requires the partial JWT issued after login.",
            operationId: "XIAMWeb.API.AuthController.mfa_challenge",
            security: [%{"partialJwt" => []}],
            responses: %{
              200 => %Response{
                description: "MFA Challenge information",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/MfaChallengeResponse")}}
              },
              400 => %Response{ # Added based on controller check
                description: "Bad Request (e.g., MFA not enabled or invalid partial token)",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/ErrorResponse")}}
              },
              401 => %Response{
                description: "Unauthorized (Invalid or missing partial token)",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/ErrorResponse")}}
              }
              # Add 500 error responses if applicable from controller
            }
          }
        },
        "/auth/mfa/verify" => %{
          post: %Operation{
            tags: ["Auth"],
            summary: "Verify MFA code",
            description: "Verifies the TOTP code. Requires the partial JWT issued after login.",
            operationId: "XIAMWeb.API.AuthController.mfa_verify",
            security: [%{"partialJwt" => []}],
            requestBody: %RequestBody{
              required: true,
              content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/MfaVerifyRequest")}}
            },
            responses: %{
              200 => %Response{
                description: "MFA verified, full token issued",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/LoginSuccessResponse")}}} # Returns full token
              },
              400 => %Response{
                description: "Bad Request (e.g., MFA not enabled or invalid code format)",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/ErrorResponse")}}
              },
              401 => %Response{
                description: "Invalid code or unauthorized (invalid partial token)",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/ErrorResponse")}}
              }
              # Add 500 error responses if applicable from controller
            }
          }
        },
        # === User Endpoints (Admin Required) ===
        "/users" => %{
          get: %Operation{
            tags: ["Users"],
            summary: "List users",
            description: "Retrieves a paginated list of users. Requires admin privileges.",
            operationId: "XIAMWeb.API.UsersController.index",
            security: [%{"jwt" => []}],
            parameters: [
              %Parameter{name: "page", in: :query, description: "Page number", required: false, schema: %Schema{type: :integer, default: 1}},
              %Parameter{name: "per_page", in: :query, description: "Users per page", required: false, schema: %Schema{type: :integer, default: 20}}
            ],
            responses: %{
              200 => %Response{
                description: "A list of users",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/UserListResponse")}}
              },
              401 => %Response{
                description: "Unauthorized",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/ErrorResponse")}}
              },
              403 => %Response{
                description: "Forbidden (Admin access required)",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/ErrorResponse")}}
              }
            }
          },
          post: %Operation{
            tags: ["Users"],
            summary: "Create user",
            description: "Creates a new user. Requires admin privileges.",
            operationId: "XIAMWeb.API.UsersController.create",
            security: [%{"jwt" => []}],
            requestBody: %RequestBody{
              required: true,
              content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/CreateUserRequest")}}
            },
            responses: %{
              201 => %Response{
                description: "User created successfully",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/CreateUserResponse")}}
              },
              400 => %Response{
                description: "Invalid user data",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/ErrorResponse")}}
              },
              401 => %Response{
                description: "Unauthorized",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/ErrorResponse")}}
              },
              403 => %Response{
                description: "Forbidden (Admin access required)",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/ErrorResponse")}}
              }
            }
          }
        },
        "/users/{id}" => %{
          parameters: [
            %Parameter{name: "id", in: :path, description: "User ID", required: true, schema: %Schema{type: :integer}}
          ],
          get: %Operation{
            tags: ["Users"],
            summary: "Get user details",
            description: "Retrieves details for a specific user. Requires admin privileges.",
            operationId: "XIAMWeb.API.UsersController.show",
            security: [%{"jwt" => []}],
            responses: %{
              200 => %Response{
                description: "User details",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/UserDetailResponse")}}
              },
              401 => %Response{
                description: "Unauthorized",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/ErrorResponse")}}
              },
              403 => %Response{
                description: "Forbidden (Admin access required)",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/ErrorResponse")}}
              },
              404 => %Response{
                description: "User not found",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/ErrorResponse")}}
              }
            }
          },
          put: %Operation{
            tags: ["Users"],
            summary: "Update user",
            description: "Updates details for a specific user. Requires admin privileges.",
            operationId: "XIAMWeb.API.UsersController.update",
            security: [%{"jwt" => []}],
            requestBody: %RequestBody{
              required: true,
              content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/UpdateUserRequest")}}
            },
            responses: %{
              200 => %Response{
                description: "User updated successfully",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/UpdateUserResponse")}}
              },
              400 => %Response{
                description: "Invalid user data",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/ErrorResponse")}}
              },
              401 => %Response{
                description: "Unauthorized",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/ErrorResponse")}}
              },
              403 => %Response{
                description: "Forbidden (Admin access required)",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/ErrorResponse")}}
              },
              404 => %Response{
                description: "User not found",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/ErrorResponse")}}
              }
            }
          },
          delete: %Operation{
            tags: ["Users"],
            summary: "Delete user",
            description: "Deletes a specific user. Requires admin privileges.",
            operationId: "XIAMWeb.API.UsersController.delete",
            security: [%{"jwt" => []}],
            responses: %{
              200 => %Response{ # Controller returns 200 on success
                description: "User deleted successfully",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/DeleteUserResponse")}}
              },
              401 => %Response{
                description: "Unauthorized",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/ErrorResponse")}}
              },
              403 => %Response{
                description: "Forbidden (Admin access required)",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/ErrorResponse")}}
              },
              404 => %Response{
                description: "User not found",
                content: %{"application/json" => %MediaType{schema: Schema.ref("#/components/schemas/ErrorResponse")}}
              }
            }
          }
        },
      } # This closes the paths map
    } # This closes the main spec map
  end # This closes the spec function
end # This closes the module
