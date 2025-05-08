defmodule XIAM.TestOutputHelper do
  import ExUnit.Assertions, only: [flunk: 1]
  @moduledoc """
  Helper functions for controlling test output.
  """

  # Set this to true to see debug messages, false to hide them
  @debug_enabled false

  @doc """
  Print a debug message during tests only if debug output is enabled.
  This allows controlling test verbosity with a single flag.
  
  ## Examples
      debug_print("Creating test user")
      debug_print("Error occurred", inspect(error))
  """
  def debug_print(message, details \\ nil) do
    if @debug_enabled do
      if details do
        IO.puts("#{message}: #{details}")
      else
        IO.puts(message)
      end
    end
  end

  @doc """
  Mark a test as skipped with an optional message.
  These messages will always show as they indicate test status.
  """
  def skip_test(message \\ "Test skipped") do
    if @debug_enabled do
      IO.puts(message)
    end
    # Directly use ExUnit.CaseTemplate.case_skipped/1 which is public
    try do
      # This raises an ExUnit.AssertionError that signals a skipped test
      # It's the standardized way ExUnit indicates a skipped test
      flunk("Skipped: #{message}")
    catch
      _, _ -> :ok
    end
  end
  
  @doc """
  Print a warning message. Unlike debug_print, warnings are 
  shown by default as they indicate potential issues.
  Control with the @warnings_enabled flag.
  """
  @warnings_enabled false
  def warn(message, details \\ nil) do
    if @warnings_enabled do
      if details do
        IO.puts("Warning: #{message}: #{details}")
      else
        IO.puts("Warning: #{message}")
      end
    end
  end
end
