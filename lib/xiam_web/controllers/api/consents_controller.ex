defmodule XIAMWeb.API.ConsentsController do
  use XIAMWeb, :controller
  alias XIAM.Consent
  alias XIAM.Consent.ConsentRecord
  alias XIAMWeb.Plugs.APIAuthorizePlug

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
    
    # Check if user has admin rights to view all consents
    has_admin_rights = APIAuthorizePlug.has_capability?(current_user, :admin_consents)
    
    filters = %{}
    
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
    
    # Add consent_type filter if provided
    filters = case params do
      %{"consent_type" => consent_type} -> Map.put(filters, :consent_type, consent_type)
      _ -> filters
    end
    
    # Add consent_given filter if provided
    filters = case params do
      %{"consent_given" => "true"} -> Map.put(filters, :consent_given, true)
      %{"consent_given" => "false"} -> Map.put(filters, :consent_given, false)
      _ -> filters
    end

    # Add active_only filter if provided
    filters = case params do
      %{"active_only" => "true"} -> Map.put(filters, :active_only, true)
      _ -> filters
    end
    
    # Get page parameters
    page = Map.get(params, "page", "1") |> String.to_integer()
    per_page = Map.get(params, "per_page", "20") |> String.to_integer()
    page_params = %{page: page, per_page: per_page}
    
    # Get paginated consent records
    page = Consent.list_consent_records(filters, page_params)
    
    render(conn, :index, consents: page.entries, page_info: %{
      page: page.page_number,
      per_page: page.page_size,
      total_pages: page.total_pages,
      total_entries: page.total_entries
    })
  end

  @doc """
  Create a new consent record.
  """
  def create(conn, %{"consent" => consent_params}) do
    current_user = conn.assigns.current_user
    
    # Add IP address and user agent information
    consent_params = consent_params
      |> Map.put("ip_address", to_string(conn.remote_ip))
      |> Map.put("user_agent", get_user_agent(conn))
    
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
    
    # Add IP address and user agent information
    consent_params = consent_params
      |> Map.put("ip_address", to_string(conn.remote_ip))
      |> Map.put("user_agent", get_user_agent(conn))
    
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

  # Get the user agent from request headers
  defp get_user_agent(conn) do
    Enum.find_value(conn.req_headers, fn
      {"user-agent", value} -> value
      _ -> nil
    end)
  end
end
