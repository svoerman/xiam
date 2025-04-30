defmodule XIAM.Test.LoggerConfig do
  @moduledoc """
  Configuration for logger during tests to suppress specific error messages.
  """
  require Logger
  import System, only: [at_exit: 1]

  @doc """
  Sets up the logger configuration for tests.
  Should be called in test_helper.exs.
  """
  def setup do
    # Store the original log level
    original_level = Logger.level()

    # Increase the log level during tests to suppress CBOR decoding errors
    # and other expected error messages in tests
    Logger.configure(level: :critical)

    # Register a function to restore the original log level when the application stops
    :persistent_term.put(:xiam_test_logger_level, original_level)
    
    # Make sure we reset the log level when tests complete
    at_exit(fn _status -> 
      original_level = :persistent_term.get(:xiam_test_logger_level)
      Logger.configure(level: original_level)
    end)
  end

  @doc """
  Runs a function with a temporarily lowered log level to allow seeing
  logs during specific tests.
  """
  def with_logs(log_level \\ :info, fun) when is_function(fun, 0) do
    # Save current level
    current_level = Logger.level()
    
    # Set temporary level for this test
    Logger.configure(level: log_level)
    
    try do
      fun.()
    after
      # Reset to previous level
      Logger.configure(level: current_level)
    end
  end
end
