defmodule XIAM.Auth.WebAuthn.Helpers do
  @moduledoc """
  Helper functions shared between WebAuthn Registration and Authentication.
  """
  @behaviour XIAM.Auth.WebAuthn.HelpersBehaviour
  require Logger

  @doc """
  Decodes JSON input if it's a binary string, otherwise returns the input.
  Handles potential Jason decoding errors.
  """
  def decode_json_input(data) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, decoded_map} when is_map(decoded_map) ->
        {:ok, decoded_map}
      {:ok, other} ->
         unless Mix.env() == :test do
           Logger.error("Invalid JSON input: Expected a JSON object, got: #{inspect(other)}")
         end
        {:error, "Invalid input format: expected JSON object"}
      {:error, reason} ->
         unless Mix.env() == :test do
           Logger.error("JSON decoding error: #{inspect(reason)}")
         end
        {:error, "Invalid JSON input: #{inspect(reason)}"}
    end
  end
  def decode_json_input(data) when is_map(data) do
    {:ok, data} # Already a map
  end
  def decode_json_input(other) do
    unless Mix.env() == :test do
      Logger.error("Invalid input type: Expected map or JSON string, got: #{inspect(other)}")
    end
    {:error, "Invalid input type: expected map or JSON string"}
  end

  @doc """
  Encodes a user ID (integer) into the binary format expected by WebAuthn (64-bit unsigned integer).
  """
  def encode_user_id(user_id) when is_integer(user_id) do
    <<user_id::unsigned-integer-size(64)>>
  end

  @doc """
  Encodes a public key map (typically COSE format) into CBOR binary.
  Handles CBOR encoding errors.
  """
  def encode_public_key(public_key) when is_map(public_key) do
    try do
      CBOR.encode(public_key)
    rescue
      e ->
        Logger.error("CBOR encoding failed for public key: #{inspect(e)}")
        # Return an error tuple or re-raise depending on desired handling
        # For now, re-raising to make it clear in the calling function
        reraise e, __STACKTRACE__
    end
  end
  # If it's already binary, assume it's correctly encoded CBOR
  def encode_public_key(public_key) when is_binary(public_key) do
    public_key
  end
  def encode_public_key(other) do
     raise "Invalid public key format for encoding: #{inspect(other)}. Expected map or binary."
  end

  @doc """
  Decodes a CBOR binary public key into an Elixir map.
  Returns the map on success, or raises an error on failure.
  """
  def decode_public_key(public_key_cbor) when is_binary(public_key_cbor) do
    case CBOR.decode(public_key_cbor) do
      {:ok, map, _rest} when is_map(map) ->
        map
      {:error, reason} ->
        Logger.error("CBOR decoding failed for public key: #{inspect(reason)}")
        raise "Failed to decode public key CBOR: #{inspect(reason)}"
      _ ->
        Logger.error("CBOR decoding returned unexpected format for public key.")
        raise "Failed to decode public key CBOR: Unexpected format"
    end
  end
  def decode_public_key(other) do
    raise "Invalid public key format for decoding: #{inspect(other)}. Expected binary."
  end
end
