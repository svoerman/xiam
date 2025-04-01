defmodule XIAMWeb.API.ConsentsController do
  use XIAMWeb, :controller
  alias XIAM.Consent
  alias XIAM.Consent.ConsentRecord
  alias XIAMWeb.Plugs.APIAuthorizePlug
  alias XIAMWeb.API.ControllerHelpers

  action_fallback XIAMWeb.FallbackController

  # Require manage_consents capability for all actions except index
  plug APIAuthorizePlug, [capability: :manage_consents] when action in [:create, :update, :delete]
  # Allow users to view their own consents
  plug APIAuthorizePlug, [capability: :read_consents] when action in [:index]

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
  def create(conn, %{"consent" => consent_params}) do
    current_user = conn.assigns.current_user
    consent_params = ControllerHelpers.add_request_metadata(conn, consent_params)
    
    with {:ok, %ConsentRecord{} = consent} <- Consent.create_consent_record(consent_params, current_user, conn) do
      render(conn, :show, consent: consent)
    end
  end

  @doc """
  Update a consent record.
  """
  def update(conn, %{"id" => id, "consent" => consent_params}) do
    current_user = conn.assigns.current_user
    consent = Consent.get_consent_record!(id)
    consent_params = ControllerHelpers.add_request_metadata(conn, consent_params)
    
    with {:ok, %ConsentRecord{} = updated_consent} <- Consent.update_consent_record(consent, consent_params, current_user, conn) do
      render(conn, :show, consent: updated_consent)
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
