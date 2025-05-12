defmodule XIAM.Hierarchy.AccessControlTest do
  # Removed compiler directive as it was causing compilation issues
  use ExUnit.Case, async: true

  # Add compiler directive to suppress unused function warnings
  @compile {:no_warn_undefined, XIAM.Hierarchy.AccessControlTest}
  
  alias XIAM.ETSTestHelper
  
  setup do
    # Ensure all required applications are started
    {:ok, _} = Application.ensure_all_started(:ecto_sql)
    {:ok, _} = Application.ensure_all_started(:postgrex)
    
    # Set up the database connection
    Ecto.Adapters.SQL.Sandbox.checkout(XIAM.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(XIAM.Repo, {:shared, self()})
    
    # Ensure ETS tables exist for Phoenix endpoint
    ETSTestHelper.ensure_ets_tables_exist()
    
    :ok
  end
  
  # Regular test cases would go here...
  
  # -------------------------------------------------------
  # The following functions are preserved for future use
  # but commented out to avoid unused function warnings
  # -------------------------------------------------------
  
  # @doc false
  # defp _retry_until_true(condition_fn, opts \\ []) do
  #   # Default options
  #   options = Keyword.merge([
  #     max_attempts: 10,
  #     delay_ms: 100
  #   ], opts)
  #   
  #   # Try the condition with retries if needed
  #   retry_until_true_impl(
  #     condition_fn,
  #     options[:max_attempts],
  #     1,
  #     options[:delay_ms]
  #   )
  # end
  
  # @doc false
  # defp retry_until_true_impl(condition_fn, max_attempts, attempt, delay_ms) do
  #   # Try the condition
  #   case condition_fn.() do
  #     true -> 
  #       true
  #     false ->
  #       if attempt < max_attempts do
  #         # Wait before retrying
  #         Process.sleep(delay_ms)
  #         
  #         # Retry
  #         retry_until_true_impl(condition_fn, max_attempts, attempt + 1, delay_ms)
  #       else
  #         # Max attempts reached
  #         false
  #       end
  #   end
  # end
  
  # @doc false
  # defp _is_duplicate_access_error?(error) do
  #   # Check if the error is a duplicate access error
  #   case error do
  #     %Ecto.ConstraintError{constraint: "access_grants_pkey"} -> true
  #     _ -> false
  #   end
  # end
end
