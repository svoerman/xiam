defmodule XIAMWeb.API.ConsentsJSON do
  @moduledoc """
  JSON view for ConsentsController responses.
  """
  alias XIAM.Consent.ConsentRecord

  @doc """
  Renders a list of consents.
  """
  def index(%{consents: consents, page_info: page_info}) do
    %{
      consents: for(consent <- consents, do: data(consent)),
      page_info: page_info
    }
  end

  @doc """
  Renders a single consent.
  """
  def show(%{consent: consent}) do
    %{consent: data(consent)}
  end

  defp data(%ConsentRecord{} = consent) do
    %{
      id: consent.id,
      consent_type: consent.consent_type,
      consent_given: consent.consent_given,
      user_id: consent.user_id,
      revoked_at: consent.revoked_at,
      inserted_at: consent.inserted_at,
      updated_at: consent.updated_at
    }
  end
end
