# Hierarchy Testing Strategy

This document outlines our behavior-focused testing approach for the XIAM Hierarchy module, designed to be robust, maintainable, and future-proof.

## Core Testing Philosophy

Our testing approach follows these key principles:

1. **Focus on Behaviors, Not Implementation**: Tests verify what the system does, not how it does it.
2. **Resilient to Refactoring**: Tests should continue to work even when implementation details change.
3. **Clear Failure Messages**: When tests fail, they clearly indicate what behavior is broken.
4. **Comprehensive Coverage**: Tests cover all critical functionality and edge cases.
5. **Maintainability**: Tests are organized and structured to be easy to understand and maintain.

## Test Structure

Our hierarchy tests are organized into several complementary test files following a behavior-focused approach:

### 1. Core Behavior Tests (`hierarchy_behavior_test.exs`)

Tests for essential behaviors from a user's perspective:
- Node creation and parent-child relationships
- Access control (granting, checking, revoking)
- Inheritance of access through the hierarchy
- Listing operations (accessible nodes, access grants)

### 2. Edge Case Tests (`hierarchy_edge_cases_test.exs`)

Tests for boundary conditions and complex scenarios:
- Very deep hierarchies
- Invalid inputs and error handling
- Circular reference prevention
- Complex access inheritance across multiple branches
- Performance with large-scale operations

### 3. API Behavior Tests (`hierarchy_api_behavior_test.exs`)

Tests for API contracts and behaviors:
- Creating and updating nodes via API
- Access control operations via API
- List operations via API
- API response structure verification
- API error handling

### 4. Integration Tests (`integration_test.exs`)

End-to-end tests for complete workflows:
- Creating hierarchies, granting access, and verifying access
- Comparing ID-based and path-based access methods
- Verifying API response structures
- Testing batch operations with error handling

## Testing Infrastructure

### Adapter Modules

We use adapter modules to abstract away implementation details:

#### `HierarchyTestAdapter`

Provides a consistent interface for testing core hierarchy behaviors:
- Creates test users, roles, and hierarchies
- Wraps hierarchy operations with implementation-agnostic interfaces
- Verifies response structures
- Handles differences between expected and actual implementations

#### `APITestAdapter`

Provides a consistent interface for testing API behaviors:
- Makes API requests with proper authentication
- Wraps API endpoints with semantic function names
- Verifies API response structures
- Sets up test environments with appropriate data

### Test Setup and Fixtures

Each test file uses appropriate setup functions to create:
- Test users and roles
- Hierarchy structures
- Access grants
- Other necessary test data

## Response Structure Verification

A critical aspect of our testing is verifying that API responses have the correct structure, especially:

1. **No Raw Ecto Associations**: Prevents JSON encoding errors
2. **Required Fields**: Ensures all necessary fields are present
3. **Derived Fields**: Verifies backward compatibility fields like `path_id`
4. **Proper Types**: Checks that fields have the correct data types

## Current vs. Ideal Implementation

### Current Implementation

The current Hierarchy module provides these core behaviors:
- Node CRUD operations
- Path-based hierarchy traversal
- Access control management
- Batch operations

### Ideal Future Architecture

Over time, we aim to evolve toward a more modular architecture with:

1. **NodeManager**: Responsible for CRUD operations on hierarchy nodes
2. **AccessManager**: Handles permissions and access grants
3. **PathCalculator**: Manages path generation and traversal operations
4. **Facade Module**: Provides a simplified API for common operations

## Testing Evolution Path

Our behavior-focused testing approach provides clear benefits during refactoring:

1. **Stable Tests During Refactoring**: Tests remain valid even when implementation details change
2. **Clear Behavior Contracts**: Tests define what the system should do, not how it does it
3. **Implementation Freedom**: Developers can change implementations as long as behaviors are preserved
4. **Faster Feedback**: Tests focus on user-visible behaviors, providing meaningful feedback when they fail

As we refactor toward a more modular architecture, our adapter-based tests will:

1. **Guide Implementation**: Tests serve as specifications for expected behavior
2. **Ensure Stability**: Existing behavior continues to work during refactoring
3. **Gradually Specialize**: The adapter implementations can evolve to match the new architecture without changing the tests

## Testing Gaps and Improvements

### Short-Term Improvements

- [ ] Enhance error case coverage
- [ ] Add performance benchmarks for critical operations
- [ ] Improve test isolation with better setup/cleanup

### Medium-Term Improvements

- [ ] Create specialized test modules as the code becomes more modular
- [ ] Add property-based tests for path operations
- [ ] Improve test data factories for more complex scenarios

### Long-Term Improvements

- [ ] Implement contract tests between components
- [ ] Add stress tests for large hierarchies
- [ ] Create visual test output for hierarchy structures

## Best Practices for Adding New Tests

When adding new tests, follow these guidelines:

1. **Focus on Behavior**: Test what the function does, not how it does it
2. **Use Helpers**: Leverage existing test helpers for common operations
3. **Verify Structure**: Always check API response structures
4. **Handle Variations**: Account for different possible implementation approaches
5. **Document Edge Cases**: Note any special cases or assumptions

## ETS Considerations

The tests should use the ETSTestHelper to ensure proper initialization of ETS tables. This is essential because:

1. Phoenix endpoints rely on ETS tables for configuration
2. Test failures can occur if these tables are not properly initialized
3. The ETSTestHelper provides a consistent way to set up the test environment

## Test Data Management

To maintain test isolation and prevent test interference:

1. **Always Use Unique Data**: Generate unique emails, names, etc.
2. **Clean Up After Tests**: Ensure tests don't leave data that affects other tests
3. **Use the Database Sandbox**: Let the DataCase handle transaction rollback

## Conclusion

This testing strategy provides a solid foundation for maintaining and improving the Hierarchy module. By focusing on behaviors rather than implementation details, our tests remain valuable through refactoring and enhancement, while ensuring the system works correctly from the user's perspective.
