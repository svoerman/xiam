defmodule XIAM.Consent.ConsentTypeTest do
  use XIAM.DataCase

  alias XIAM.Consent.ConsentType

  describe "consent_type schema" do
    test "changeset with valid attributes" do
      valid_attrs = %{
        name: "marketing",
        description: "Marketing communications consent",
        required: false,
        active: true
      }

      changeset = ConsentType.changeset(%ConsentType{}, valid_attrs)
      assert changeset.valid?
    end

    test "changeset with invalid attributes" do
      invalid_attrs = %{
        description: "Missing name field",
        required: false,
        active: true
      }

      changeset = ConsentType.changeset(%ConsentType{}, invalid_attrs)
      assert !changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
    end

    test "changeset with only name attribute" do
      minimal_attrs = %{name: "minimal_consent_type"}

      changeset = ConsentType.changeset(%ConsentType{}, minimal_attrs)
      assert changeset.valid?
    end

    test "changeset sets default values" do
      attrs = %{name: "defaults_test"}

      changeset = ConsentType.changeset(%ConsentType{}, attrs)
      
      # These fields should get their default values
      assert changeset.changes[:required] == nil # Default handled by schema
      assert changeset.changes[:active] == nil # Default handled by schema
      
      # Get the default values from the schema
      record = Ecto.Changeset.apply_changes(changeset)
      assert record.required == false
      assert record.active == true
    end
  end
end