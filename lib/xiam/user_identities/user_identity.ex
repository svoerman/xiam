defmodule XIAM.UserIdentities.UserIdentity do
  use Ecto.Schema
  use PowAssent.Ecto.UserIdentities.Schema, user: XIAM.Users.User

  schema "user_identities" do
    pow_assent_user_identity_fields()

    timestamps()
  end
end
