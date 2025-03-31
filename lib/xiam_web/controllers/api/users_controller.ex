defmodule XIAMWeb.API.UsersController do
  @moduledoc """
  Controller for API user management endpoints.
  Provides CRUD operations for users with proper authorization.
  """

  use XIAMWeb, :controller

  alias XIAM.Users.User
  alias Xiam.Rbac.Role
  alias XIAM.Repo
  alias XIAM.Jobs.AuditLogger
  import Ecto.Query

  @doc """
  Lists all users with optional pagination and filtering.
  Requires the "list_users" capability.
  """
  def index(conn, params) do
    # Extract pagination parameters with defaults
    page = Map.get(params, "page", "1") |> String.to_integer()
    per_page = Map.get(params, "per_page", "20") |> String.to_integer()

    # Calculate offset
    offset = (page - 1) * per_page

    # Build query with optional filters
    query = from u in User,
            left_join: r in assoc(u, :role),
            preload: [role: r]

    # Apply filters if provided
    query = if params["role_id"], do: where(query, [u], u.role_id == ^params["role_id"]), else: query
    query = if params["email"], do: where(query, [u], ilike(u.email, ^"%#{params["email"]}%")), else: query

    # Get total count
    total_count = Repo.aggregate(query, :count, :id)

    # Apply pagination
    query = query
            |> limit(^per_page)
            |> offset(^offset)
            |> order_by([u], desc: u.inserted_at)

    # Execute query
    users = Repo.all(query)

    # Format the users for JSON response, excluding sensitive fields
    users_json = Enum.map(users, fn user ->
      %{
        id: user.id,
        email: user.email,
        mfa_enabled: user.mfa_enabled,
        role: user.role && %{id: user.role.id, name: user.role.name},
        inserted_at: user.inserted_at,
        updated_at: user.updated_at
      }
    end)

    # Return paginated response
    conn
    |> put_status(:ok)
    |> json(%{
      success: true,
      data: users_json,
      meta: %{
        page: page,
        per_page: per_page,
        total: total_count,
        total_pages: ceil(total_count / per_page)
      }
    })
  end

  @doc """
  Retrieves a specific user by ID.
  Requires the "view_user" capability.
  """
  def show(conn, %{"id" => id}) do
    case Repo.get(User, id) |> Repo.preload(:role) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "User not found"})

      user ->
        # Log the user view
        current_user = conn.assigns.current_user
        AuditLogger.log_action("api_user_view", current_user.id, %{target_user_id: user.id}, current_user.email)

        # Format the user for JSON response, excluding sensitive fields
        user_json = %{
          id: user.id,
          email: user.email,
          mfa_enabled: user.mfa_enabled,
          role: user.role && %{id: user.role.id, name: user.role.name},
          inserted_at: user.inserted_at,
          updated_at: user.updated_at
        }

        conn
        |> put_status(:ok)
        |> json(%{
          success: true,
          data: user_json
        })
    end
  end

  @doc """
  Creates a new user.
  Requires the "create_user" capability.
  """
  def create(conn, %{"user" => user_params}) do
    # Ensure role_id is valid if provided
    user_params = if user_params["role_id"] do
      role = Repo.get(Role, user_params["role_id"])
      if role, do: user_params, else: Map.delete(user_params, "role_id")
    else
      user_params
    end

    current_user = conn.assigns.current_user

    # Create user with Pow
    case Pow.Ecto.Context.create(User, user_params) do
      {:ok, user} ->
        # Log the user creation
        AuditLogger.log_action("api_user_create", current_user.id, %{
          new_user_id: user.id,
          new_user_email: user.email
        }, current_user.email)

        conn
        |> put_status(:created)
        |> json(%{
          success: true,
          data: %{
            id: user.id,
            email: user.email
          },
          message: "User created successfully"
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: "Failed to create user",
          details: error_details(changeset)
        })
    end
  end

  @doc """
  Updates an existing user.
  Requires the "update_user" capability.
  """
  def update(conn, %{"id" => id, "user" => user_params}) do
    current_user = conn.assigns.current_user

    case Repo.get(User, id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "User not found"})

      user ->
        # Remove password fields if they're empty
        user_params = if user_params["password"] == "" do
          Map.drop(user_params, ["password", "password_confirmation"])
        else
          user_params
        end

        # Handle role_id specially
        {role_id, user_params} = Map.pop(user_params, "role_id")

        # Update basic user fields with Pow
        case Pow.Ecto.Context.update(User, user, user_params) do
          {:ok, updated_user} ->
            # Update role if provided and valid
            updated_user = if role_id do
              case User.role_changeset(updated_user, %{role_id: role_id}) |> Repo.update() do
                {:ok, user_with_role} -> user_with_role
                {:error, _} -> updated_user
              end
            else
              updated_user
            end

            # Log the user update
            AuditLogger.log_action("api_user_update", current_user.id, %{
              target_user_id: updated_user.id,
              changes: Map.drop(user_params, ["password", "password_confirmation"])
            }, current_user.email)

            conn
            |> put_status(:ok)
            |> json(%{
              success: true,
              data: %{
                id: updated_user.id,
                email: updated_user.email
              },
              message: "User updated successfully"
            })

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{
              error: "Failed to update user",
              details: error_details(changeset)
            })
        end
    end
  end

  @doc """
  Deletes a user.
  Requires the "delete_user" capability.
  """
  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    case Repo.get(User, id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "User not found"})

      user ->
        # Prevent self-deletion
        if user.id == current_user.id do
          conn
          |> put_status(:forbidden)
          |> json(%{error: "Cannot delete your own account"})
        else
          # Log the deletion attempt before actually deleting
          AuditLogger.log_action("api_user_delete", current_user.id, %{
            target_user_id: user.id,
            target_user_email: user.email
          }, current_user.email)

          case Repo.delete(user) do
            {:ok, _} ->
              conn
              |> put_status(:ok)
              |> json(%{
                success: true,
                message: "User deleted successfully"
              })

            {:error, changeset} ->
              conn
              |> put_status(:unprocessable_entity)
              |> json(%{
                error: "Failed to delete user",
                details: error_details(changeset)
              })
          end
        end
    end
  end

  # Helper function to format changeset errors
  defp error_details(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
