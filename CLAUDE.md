# XIAM Project Guide for Claude

## Build & Run Commands
- `mix setup` - Install dependencies and setup database
- `mix phx.server` - Start Phoenix server
- `iex -S mix phx.server` - Start with interactive Elixir shell

## Lint & Format
- `mix format` - Format code according to Elixir conventions

## Test Commands
- `mix test` - Run all tests
- `mix test path/to/file:line_number` - Run a specific test
- `mix test --trace` - Run tests with detailed trace output

## Code Style Guidelines
- **Modules**: Use proper `@moduledoc` and `@doc` documentation
- **Functions**: Follow snake_case naming, prefix private functions with `defp`
- **Error Handling**: Return `{:ok, result}` or `{:error, reason}` tuples
- **Contexts**: Keep domain logic in appropriate context modules
- **Imports**: Group by type (Phoenix, Ecto, etc.) with core Elixir imports first
- **Typing**: Use `@spec` for public API functions
- **Testing**: Mark tests with `async: true` when possible for PostgreSQL tests
- **LiveView**: Use .html.heex templates with component-based structure