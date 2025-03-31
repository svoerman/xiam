## CIAM Fine-Grained Access Control Implementation Plan

### Feature Overview

Extend the existing Elixir & Windsurf-based CIAM application to provide fine-grained, hierarchical access control with:

- Permissions scoped by combination of entity type, entity ID, and user role.
- Products defined with multiple capabilities (sets of strings with descriptions).

### 1. Data Models

#### EntityAccess
Stores fine-grained access control information.
- `id` (integer)
- `user_id` (integer)
- `entity_type` (string)
- `entity_id` (integer)
- `role` (string)

#### Product
Defines products and associates multiple capabilities.
- `id` (integer)
- `product_name` (string, unique)

#### Capability
Defines individual capabilities associated with products.
- `id` (integer)
- `product_id` (integer, foreign key to Product)
- `capability_name` (string)
- `description` (string)

### 2. API Specification

#### Set User Access
- `POST /api/access`
- Payload:
  - `user_id`
  - `entity_type`
  - `entity_id`
  - `role`
- Action: Creates or updates user access to a specific entity.

#### Get User Access
- `GET /api/access?user_id={user_id}`
- Action: Retrieves user's current access details for entities and the assigned role.

#### Manage Product Capabilities

##### List Product Capabilities
- `GET /api/products/{product_id}/capabilities`
- Action: Lists all capabilities associated with the specified product.

### 3. Capability Resolution Logic
- Upon user action request, capabilities are computed dynamically:
  - Retrieve user's role for entity.
  - Retrieve capabilities defined by products (handled by client logic).
  - Combine role-based and product-based capabilities to determine effective permissions.

### 4. Admin UI Implementation
- Dashboard to:
  - Manage user access (assign access and roles to entities).
  - Manage products and their capabilities (define multiple capability names and descriptions per product).
- Views:
  - User Access Assignment: Lists and manages role assignments per entity.
  - Product Management: Lists products, adds capabilities, and edits capability details.

### 5. Security & Performance Considerations
- Cache resolved permissions per user/entity combination to enhance performance.
- Implement comprehensive logging for permission changes.
- Add audit trails for role and product capability assignments to ensure transparency.

