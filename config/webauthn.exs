import Config

# WebAuthn (Passkey) Configuration
config :wax_,
  # The name of the Relying Party (your application)
  rp_name: "XIAM",
  
  # The ID of the Relying Party (should be your domain)
  # In development, this is usually "localhost"
  rp_id: System.get_env("WEBAUTHN_RP_ID", "localhost"),
  
  # The origin of the Relying Party (your application URL)
  # In development, this matches the Phoenix endpoint port
  origin: System.get_env("WEBAUTHN_ORIGIN", "http://localhost:4100"),
  
  # Timeout for WebAuthn operations (in milliseconds)
  timeout: 60000,
  
  # User verification requirement
  # Can be "preferred", "required", or "discouraged"
  user_verification: "preferred",
  
  # Attestation conveyance preference
  # Can be "none", "indirect", "direct", or "enterprise"
  attestation: "none"
