# Test Coverage Improvement Plan

## 1. API Controllers (Highest Priority)

### `lib/xiam_web/controllers/api/hierarchy_controller.ex` (24.4%, 148 missed lines)
This controller has the most missed lines (148) and is a critical part of the API. The low coverage suggests many API endpoints aren't being properly tested.

**Recommendation:** Create additional tests for:
- Specific error cases and edge conditions
- Data validation scenarios
- Authentication and authorization failures

### `lib/xiam_web/controllers/api/passkey_controller.ex` (16.6%, 110 missed lines)
This controller has very low coverage and handles important authentication functionality.

**Recommendation:** Add tests for:
- Passkey registration failures
- Authentication with invalid credentials
- Edge cases in the WebAuthn flow

### `lib/xiam_web/controllers/api/hierarchy_access_controller.ex` (30.0%, 7 missed lines)
While it has fewer missed lines, this controller handles important access control functionality.

**Recommendation:** Expand tests to cover error cases and authorization failures.

## 2. Core Functional Modules

### `lib/xiam/hierarchy/batch_operations.ex` (0.0%, 56 missed lines)
This module has no test coverage, yet batch operations are critical for efficient hierarchy management.

**Recommendation:** Create a dedicated test file for batch operations, testing both success paths and error handling.

### `lib/xiam/hierarchy/path_calculator.ex` (34.2%, 23 missed lines)
Path calculation is fundamental to hierarchy functionality.

**Recommendation:** Add tests for edge cases:
- Deeply nested paths
- Invalid paths
- Path resolution failures

### `lib/xiam/users.ex` (34.3%, 21 missed lines)
User management is a critical part of any auth system.

**Recommendation:** Add tests for:
- User creation/update with invalid data
- User deletion and related cleanup
- User search and filtering

## 3. LiveView Components

### `lib/xiam_web/live/admin/hierarchy_live.ex` (0.0%, 161 missed lines)
The admin hierarchy management UI has no test coverage.

**Recommendation:** Add LiveView tests that simulate:
- Creating/updating/deleting nodes
- Moving nodes
- Permission changes

### `lib/xiam_web/components/form_components.ex` (10.5%, 51 missed lines)
Form components are used throughout the application.

**Recommendation:** Create tests for form validation, submission, and error handling.

### `lib/xiam_web/live/account_settings_live.ex` (43.7%, 36 missed lines)
User account settings are important for security.

**Recommendation:** Add tests for:
- Password changes
- Profile updates
- Security settings

## 4. WebAuthn Authentication

### `lib/xiam/auth/webauthn/credential_manager.ex` (59.3%, 13 missed lines)
### `lib/xiam/auth/webauthn/authentication.ex` (60.8%, 9 missed lines)

**Recommendation:** Create more comprehensive tests for the WebAuthn authentication flow, including failure cases and security validations.

## 5. Infrastructure and Caching

### `lib/xiam/cache/hierarchy_cache.ex` (51.9%, 50 missed lines)
Caching is critical for performance but has only moderate coverage.

**Recommendation:** Add tests for:
- Cache invalidation
- Cache misses
- Concurrent access patterns

## Implementation Strategy

When implementing these tests, I recommend:

1. **Focus on behavior, not implementation**: Test what the code does, not how it does it
2. **Add resilient testing patterns**: Use the `XIAM.ResilientTestHelper.safely_execute_db_operation` pattern established in previous tests
3. **Test error paths**: Many missed lines are likely in error handling code
4. **Test authorization boundaries**: Ensure unauthorized access is properly rejected
5. **Use meaningful data**: Create test data that exercises specific edge cases
