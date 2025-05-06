# XIAM API Response Best Practices

## JSON Encoding Patterns

### Handling Ecto Schemas in API Responses

When returning Ecto schema data through API endpoints, it's important to ensure that:
1. No unloaded associations are included (prevents `Jason.EncodeError` errors)
2. Only explicitly defined fields are exposed (prevents leaking internal data)
3. Consistent field naming is used across all endpoints
4. Derived fields are properly calculated based on the underlying data

### Recommended Pattern for Node Data

```elixir
def to_json(node) do
  # Create an explicit map with only the fields needed, don't use Map.from_struct/1
  %{
    id: node.id,
    path: node.path,
    name: node.name,
    node_type: node.node_type,
    parent_id: node.parent_id,
    # Include derived fields as needed
    # Never include raw associations
  }
end
```

### Recommended Pattern for Access Grants

```elixir
def access_grant_to_json(access) do
  %{
    id: access.id,
    user_id: access.user_id,
    role_id: access.role_id,
    # For path-based access grants, include path_id for backward compatibility
    access_path: access.access_path,
    path_id: Path.basename(access.access_path),
    # Include timestamps if needed
    inserted_at: access.inserted_at,
    updated_at: access.updated_at
  }
end
```

## Common API Response Structures

### Success Responses

For list endpoints:
```json
{
  "data": [
    { ... item 1 ... },
    { ... item 2 ... }
  ],
  "meta": {
    "total_count": 50,
    "page": 1,
    "per_page": 20
  }
}
```

For single item endpoints:
```json
{
  "data": { ... item data ... }
}
```

For operations with simple success indicators:
```json
{
  "success": true
}
```

### Error Responses

For validation errors:
```json
{
  "errors": {
    "field_name": ["Error message"]
  }
}
```

For generic errors:
```json
{
  "error": "Error message"
}
```

## Testing API Responses

When writing tests for API endpoints, ensure that:

1. The structure of the response matches the expected format
2. No raw associations are included in the response
3. All required fields are present
4. Field values match the expected data

Example test assertion:
```elixir
conn = get(conn, ~p"/api/hierarchy/users/#{user.id}/accessible-nodes")
assert %{"data" => nodes} = json_response(conn, 200)

# Verify node structure
node = Enum.find(nodes, fn n -> n["id"] == team.id end)
assert node["id"] == team.id
assert node["path"] == team.path
assert node["name"] == team.name
assert node["node_type"] == team.node_type

# Verify no raw associations are included
refute Map.has_key?(node, "parent")
refute Map.has_key?(node, "children")
```

## Known Issues and Solutions

### Issue: Unloaded Associations

**Problem**: When an Ecto schema with associations is passed directly to `Jason.encode!/1`, you might encounter errors like:
```
** (Jason.EncodeError) cannot encode association :parent from XIAM.Hierarchy.Node [...] to JSON
```

**Solution**: Always map schemas to plain maps with only the needed fields before encoding:
```elixir
def show(conn, %{"id" => id}) do
  node = Hierarchy.get_node(id)
  
  # WRONG: 
  # render(conn, :show, node: node)
  
  # CORRECT:
  safe_node = %{
    id: node.id,
    path: node.path,
    name: node.name,
    node_type: node.node_type,
    parent_id: node.parent_id,
    # Include other fields as needed
  }
  render(conn, :show, node: safe_node)
end
```

### Issue: Backward Compatibility

**Problem**: When refactoring schemas or models, existing API clients may rely on specific field names.

**Solution**: Include derived fields to maintain backward compatibility:

```elixir
# If we changed from node_id to access_path
def to_json(access_grant) do
  %{
    id: access_grant.id,
    access_path: access_grant.access_path,
    # Include node_id for backward compatibility
    node_id: Path.basename(access_grant.access_path)
  }
end
```

## Future Considerations

1. Consider implementing a formal schema validation library like `ex_json_schema`
2. Create view modules for each controller to encapsulate JSON structure logic
3. Add schema documentation using OpenAPI/Swagger
4. Implement versioning for API endpoints to support long-term changes
