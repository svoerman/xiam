defmodule XIAMWeb.API.ConsentsController do
  use XIAMWeb, :controller
  alias XIAM.Consent
  alias XIAM.Consent.ConsentRecord
  alias XIAMWeb.Plugs.APIAuthorizePlug
  alias XIAMWeb.API.ControllerHelpers
  alias XIAMWeb.Plugs.AuthHelpers # Needed for manual capability check

  action_fallback XIAMWeb.FallbackController

  # Apply authorization plugs with specific capabilities
  # Allow any authenticated user to attempt these actions,
  # ownership/admin checks happen within the action.
  plug APIAuthorizePlug, nil when action in [:index, :create, :update]
  # Deletion requires a specific capability checked by the plug
  plug APIAuthorizePlug, :delete_consent when action in [:delete]

  @doc """
  List consent records with optional filtering.
  Users can only see their own consents unless they have admin capabilities.
  """
  def index(conn, params) do
    current_user = conn.assigns.current_user
    # Use AuthHelpers for consistency
    has_admin_rights = AuthHelpers.has_capability?(current_user, :admin_consents)

    # Define allowed filters and their parsers
    allowed_filters = [
      {"consent_type", :consent_type, :string},
      {"consent_given", :consent_given, :boolean},
      {"active_only", :active_only, :boolean}
    ]

    # Build filters from params
    filters = ControllerHelpers.build_filters(params, allowed_filters)

    # Apply user scoping unless admin
    filters = unless has_admin_rights do
      Map.put(filters, :user_id, current_user.id)
    else
      # Admin can filter by user_id if provided
      case params do
        %{"user_id" => user_id} -> Map.put(filters, :user_id, user_id)
        _ -> filters
      end
    end

    # Get paginated consent records using original context function
    page_params = ControllerHelpers.pagination_params(params)
    page = Consent.list_consent_records(filters, page_params)

    render(conn, :index, consents: page.entries, page_info: ControllerHelpers.pagination_info(page))
  end

  @doc """
  Create a new consent record.
  """
  def create(conn, %{"consent" => consent_params}) do
    do_create(conn, consent_params)
  end

def create(conn, params) do
    if is_map(params) && (Map.has_key?(params, "consent_type") || Map.has_key?(params, "consent_given")) do
      do_create(conn, params)
    else
      conn
      |> put_status(:bad_request)
      |> json(%{
        error: "Missing required consent fields",
        received_params: params,
        help: "Parameters should include consent_type and consent_given"
      })
    end
  end

defp do_create(conn, consent_params) do
    current_user = conn.assigns.current_user

    # Re-introduce ownership check: Users can only create for self unless admin
    has_admin_rights = AuthHelpers.has_capability?(current_user, :admin_consents) ||
                     AuthHelpers.has_capability?(current_user, :manage_consents)
    # Call local helper function
    specified_user_id = get_user_id_from_params(consent_params)

    if specified_user_id && specified_user_id != current_user.id && !has_admin_rights do
      AuthHelpers.forbidden_response(conn, "You can only create consent records for yourself")
    else
      # Ensure consent is created for current user if not specified or if admin creating for someone
      user_id_to_set = specified_user_id || current_user.id
      # Add metadata: Call helper directly, passing conn first
      consent_params_with_metadata = ControllerHelpers.add_request_metadata(conn, consent_params)
      consent_params_final = Map.put(consent_params_with_metadata, "user_id", user_id_to_set)

      # Use original context function
      with {:ok, %ConsentRecord{} = consent} <- Consent.create_consent_record(consent_params_final) do
        render(conn, :show, consent: consent)
      end
    end
  end

  @doc """
  Update a consent record.
  """
  def update(conn, %{"id" => id, "consent" => consent_params}) do
    do_update(conn, id, consent_params)
  end

def update(conn, %{"id" => id} = params) do
    consent_params = Map.drop(params, ["id"])
    if map_size(consent_params) > 0 do
      do_update(conn, id, consent_params)
    else
      conn
      |> put_status(:bad_request)
      |> json(%{error: "Missing consent parameters"})
    end
  end

defp do_update(conn, id, consent_params) do
    current_user = conn.assigns.current_user
    # Fetch consent record first to check ownership (use bang version)
    consent = Consent.get_consent_record!(id)
    # Re-introduce ownership check
    has_admin_rights = AuthHelpers.has_capability?(current_user, :admin_consents) ||
                        AuthHelpers.has_capability?(current_user, :manage_consents)

    if consent.user_id != current_user.id && !has_admin_rights do
      AuthHelpers.forbidden_response(conn, "You can only modify your own consent records")
    else
      consent_params = ControllerHelpers.add_request_metadata(conn, consent_params)

      # Use original context function
      with {:ok, %ConsentRecord{} = updated_consent} <- Consent.update_consent_record(consent, consent_params) do
        render(conn, :show, consent: updated_consent)
      end
    end
  end

  @doc """
  Delete (revoke) a consent record.
  Requires :delete_consent capability (checked by plug).
  Ownership check might still be needed depending on capability granularity.
  """
  def delete(conn, %{"id" => id}) do
    # Assuming for now :delete_consent is admin-level.
    # Use bang version to fetch or raise
    consent = Consent.get_consent_record!(id)
    # Use original context function
    with {:ok, %ConsentRecord{}} <- Consent.revoke_consent(consent) do
      send_resp(conn, :no_content, "")
    end
  end

  # Helper function to safely extract user_id from params
  defp get_user_id_from_params(params) when is_map(params) do
    user_id = params["user_id"] || params[:user_id]
    case user_id do
      nil -> nil
      id when is_binary(id) ->
        case Integer.parse(id) do
          {parsed_id, _} -> parsed_id
          :error -> nil
        end
      id when is_integer(id) -> id
      _ -> nil
    end
  rescue
    _ -> nil # Return nil on any error during extraction
  end
end
