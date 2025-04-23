defimpl Jason.Encoder, for: Wax.Challenge do
  def encode(challenge, opts) do
    challenge
    |> Map.from_struct()
    |> Map.take([:bytes, :rp_id, :origin, :timeout, :user_verification, :attestation, :allow_credentials])
    |> Map.update!(:bytes, &Base.url_encode64(&1, padding: false))
    |> Jason.Encode.map(opts)
  end
end
