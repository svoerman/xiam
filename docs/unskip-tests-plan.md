# Test Un-skip Plan

This document outlines our step-by-step approach to un-skipping currently skipped tests, leveraging the resilient test setup.

## 1. Audit & Catalog
- Grep for `@tag :skip` across `test/` to list all skipped test files.
- Group by feature area: API controllers, hierarchy modules, auth, etc.

### Currently Skipped Tests (as of 2025-05-12):
(All tests in `test/xiam_web/live/admin/audit_logs_live_test.exs` have been successfully unskipped and fixed as of 2025-05-12).

The next step is to search for any remaining `@tag :skip` instances in the `test/` directory.

## 2. Module-by-Module Rollout
1. **Select a small module** (few dependencies) and remove its skip tags.
2. **Run**:
   ```bash
   mix test path/to/that_file.exs
   ```
3. **Fix failures** by:
   - Using `ResilientTestHelper.safely_execute_db_operation/2` for DB ops.
   - Relying on `ResilientTestCase` (or `ConnCase`, `DataCase`, `LiveViewTestHelper`) for sandbox & ETS.
   - Replacing `System.unique_integer` with timestamped IDs.
   - Centralizing setup in fixtures (`AccessTestFixtures`, `hierarchy_test_adapter`).
   - Using flexible assertions (`assert_access_granted`, etc.).
4. **Verify & commit** before moving on.
5. Repeat for next module.

## 3. Cross-Cutting Concerns
- API tests use `ConnCase`; LiveView tests use `LiveViewTestHelper`.
- Ensure ETS and repo setup in those CaseTemplates.

## 4. Cleanup
- Remove now-unused fixtures or imports.
- Delete leftover `@tag :skip` macros.

## 5. Progress Tracking
Maintain a checklist (`docs/unskip-tests-checklist.md`) and tick off as each file passes.
