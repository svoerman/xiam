defmodule XIAMWeb.API.ConsentsController do
  use XIAMWeb, :controller
  alias XIAM.Consent
  alias XIAM.Consent.ConsentRecord
  alias XIAMWeb.Plugs.APIAuthorizePlug
  alias XIAMWeb.API.ControllerHelpers

  action_fallback XIAMWeb.FallbackController

  # Only require manage_consents capability for admin actions
  # Regular users can create/manage their own consents without special permissions
  plug APIAuthorizePlug, [capability: :manage_consents] when action in [:delete]
  # Allow authenticated users to view their own consents
  plug APIAuthorizePlug when action in [:index, :create, :update]

  @doc """
  List consent records with optional filtering.
  Users can only see their own consents unless they have admin capabilities.
  """
  def index(conn, params) do
    current_user = conn.assigns.current_user
    has_admin_rights = APIAuthorizePlug.has_capability?(current_user, :admin_consents)
    
    # Define allowed filters and their parsers
    allowed_filters = [
      {"consent_type", :consent_type, :string},
      {"consent_given", :consent_given, :boolean},
      {"active_only", :active_only, :boolean}
    ]
    
    # Build filters from params
    filters = ControllerHelpers.build_filters(params, allowed_filters)
    
    # Non-admin users can only see their own consents
    filters = unless has_admin_rights do
      Map.put(filters, :user_id, current_user.id)
    else
      # Admin can filter by user_id if provided
      case params do
        %{"user_id" => user_id} -> Map.put(filters, :user_id, user_id)
        _ -> filters
      end
    end
    
    # Get paginated consent records
    page_params = ControllerHelpers.pagination_params(params)
    page = Consent.list_consent_records(filters, page_params)
    
    render(conn, :index, consents: page.entries, page_info: ControllerHelpers.pagination_info(page))
  end

  @doc """
  Create a new consent record.
  """
  # Handle both formats: with or without "consent" wrapper
  def create(conn, %{"consent" => consent_params}) do
    do_create(conn, consent_params)
  end
  
  # Catch-all clause for any other parameter format
  def create(conn, params) do
    # Debug the incoming parameters
    IO.inspect(params, label: "Received params in create")
    
    # Determine if we have consent fields at the top level
    if is_map(params) && (Map.has_key?(params, "consent_type") || Map.has_key?(params, "consent_given")) do
      do_create(conn, params)
    else
      # Return helpful error with the actual params received
      conn
      |> put_status(:bad_request)
      |> json(%{
        error: "Missing required consent fields",
        received_params: params,
        help: "Parameters should include consent_type and consent_given"
      })
    end
  end
  
  # Private function that handles the actual consent creation
  defp do_create(conn, consent_params) do
    current_user = conn.assigns.current_user
    
    # Check if user is trying to create a consent for another user
    has_admin_rights = APIAuthorizePlug.has_capability?(current_user, :admin_consents) || 
                     APIAuthorizePlug.has_capability?(current_user, :manage_consents)
    specified_user_id = get_user_id_from_params(consent_params)
    
    if specified_user_id && specified_user_id != current_user.id && !has_admin_rights do
      conn
      |> put_status(:forbidden)
      |> json(%{error: "You can only create consent records for yourself"})
    else
      # Ensure consent is created for current user by explicitly setting the user_id
      consent_params = consent_params 
                      |> Map.put("user_id", current_user.id)
      
      # Add request metadata (IP address, user agent)
      consent_params = ControllerHelpers.add_request_metadata(conn, consent_params)
      
      with {:ok, %ConsentRecord{} = consent} <- Consent.create_consent_record(consent_params, current_user, conn) do
        render(conn, :show, consent: consent)
      end
    end
  end
  
  # Helper function to safely extract user_id from params
  defp get_user_id_from_params(params) do
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
  end

  @doc """
  Update a consent record.
  """
  # Handle params with "consent" wrapper
  def update(conn, %{"id" => id, "consent" => consent_params}) do
    do_update(conn, id, consent_params)
  end
  
  # Handle direct params (without "consent" wrapper)
  def update(conn, %{"id" => id} = params) do
    # Remove the ID from params to get just the consent parameters
    consent_params = Map.drop(params, ["id"])
    # Only proceed if there are consent params left
    if map_size(consent_params) > 0 do
      do_update(conn, id, consent_params)
    else
      conn
      |> put_status(:bad_request)
      |> json(%{error: "Missing consent parameters"})
    end
  end
  
  # Private function that handles the actual update
  defp do_update(conn, id, consent_params) do
    current_user = conn.assigns.current_user
    consent = Consent.get_consent_record!(id)
    
    # Ensure users can only modify their own consents unless they have admin rights
    has_admin_rights = APIAuthorizePlug.has_capability?(current_user, :admin_consents) || 
                     APIAuthorizePlug.has_capability?(current_user, :manage_consents)
    
    if consent.user_id != current_user.id && !has_admin_rights do
      conn
      |> put_status(:forbidden)
      |> json(%{error: "You can only modify your own consent records"})
    else
      consent_params = ControllerHelpers.add_request_metadata(conn, consent_params)
      
      with {:ok, %ConsentRecord{} = updated_consent} <- Consent.update_consent_record(consent, consent_params, current_user, conn) do
        render(conn, :show, consent: updated_consent)
      end
    end
  end

  @doc """
  Delete (revoke) a consent record.
  """
  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    consent = Consent.get_consent_record!(id)
    
    with {:ok, %ConsentRecord{}} <- Consent.revoke_consent(consent, current_user, conn) do
      send_resp(conn, :no_content, "")
    end
  end
end
