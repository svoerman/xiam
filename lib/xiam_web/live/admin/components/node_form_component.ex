defmodule XIAMWeb.Admin.Components.NodeFormComponent do
  @moduledoc """
  LiveView component for node creation and editing forms.
  Extracted from the original HierarchyLive module to improve maintainability.
  """
  use XIAMWeb, :live_component
  
  import XIAMWeb.Components.UI.Button
  # Remove unused import
  # import XIAMWeb.Components.UI.Modal
  import XIAMWeb.CoreComponents, except: [button: 1, modal: 1]
  
  alias XIAM.Hierarchy.Node
  
  def render(assigns) do
    ~H"""
    <div>
      <.form for={@form} phx-submit="save_node" phx-change="validate_node">
        <div class="space-y-4">
          <div>
            <.input 
              field={@form[:name]} 
              label="Node Name" 
              required 
              placeholder="Enter node name"
            />
          </div>
          
          <div>
            <.input 
              field={@form[:node_type]} 
              label="Node Type" 
              type="select" 
              options={[{"", "-- Select Type --"} | node_type_options(@suggested_node_types)]} 
            />
            <.hint>Used for visual identification and grouping</.hint>
          </div>
          
          <div class="hidden">
            <.input field={@form[:parent_id]} type="hidden" />
          </div>
          
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              Metadata
            </label>
            <.json_editor 
              id="node-metadata-editor"
              value={get_metadata_json(@form[:metadata].value)}
              phx-hook="JsonEditor"
              data-target={@form[:metadata].id}
            />
            <.input field={@form[:metadata]} type="hidden" />
            <.hint>Optional JSON metadata for this node</.hint>
          </div>
          
          <div class="pt-4 flex justify-end space-x-3">
            <.button type="button" phx-click="close_modal" variant="secondary">
              Cancel
            </.button>
            <.button type="submit" variant="default">
              Save Node
            </.button>
          </div>
        </div>
      </.form>
    </div>
    """
  end
  
  # Helper functions
  
  defp node_type_options(suggested_types) do
    Enum.map(suggested_types, fn type -> {type, String.capitalize(type)} end)
  end
  
  defp get_metadata_json(nil), do: "{}"
  defp get_metadata_json(metadata) when is_map(metadata) do
    Jason.encode!(metadata, pretty: true)
  rescue
    _ -> "{}"
  end
  defp get_metadata_json(_), do: "{}"
  
  def json_editor(assigns) do
    ~H"""
    <div
      id={@id}
      phx-update="ignore"
      {@rest}
    >
      <div
        class="w-full h-32 border border-gray-300 rounded-md p-2 font-mono text-sm"
        style="min-height: 8rem;"
      ><%= @value %></div>
    </div>
    """
  end
  
  def hint(assigns) do
    ~H"""
    <p class="mt-1 text-sm text-gray-500">
      <%= render_slot(@inner_block) %>
    </p>
    """
  end
  
  # Client callbacks
  
  def update(%{node: node, action: action} = assigns, socket) do
    changeset = case action do
      :new -> Node.changeset(%Node{}, %{})
      :edit -> Node.changeset(node, %{})
    end
    
    form = to_form(changeset)
    
    {:ok, socket
      |> assign(assigns)
      |> assign(:form, form)
    }
  end
  
  # To be called from the parent LiveView
  def validate_changeset(socket, params) do
    node = socket.assigns.node || %Node{}
    changeset = 
      node
      |> Node.changeset(params)
      |> Map.put(:action, :validate)
      
    form = to_form(changeset)
    assign(socket, form: form)
  end
end
