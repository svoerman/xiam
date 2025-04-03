<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/images/logo_for_dark_bg.png">
    <source media="(prefers-color-scheme: light)" srcset="docs/images/logo_for_light_bg.png">
    <img alt="XIAM Logo" src="docs/images/logo_for_light_bg.png" width="256">
  </picture>
</p>

# XIAM Documentation

Installation and Usage Guide

## Introduction

XIAM (eXtensible Identity and Access Management) is a platform built with Elixir and Phoenix, designed to provide robust authentication, authorization, and user management capabilities for modern web applications.

Key features include:

*   User Registration & Login (Email/Password)
*   Multi-Factor Authentication (MFA / TOTP)
*   Role-Based Access Control (RBAC) with Roles and Capabilities
*   Admin Panel for managing Users, Roles, and Capabilities
*   JWT-based API Authentication
*   Background Job Processing (via Oban)

## Installation

Follow these steps to get a local development instance of XIAM running.

### Prerequisites

*   Elixir (~> 1.15)
*   Erlang/OTP (~> 26)
*   PostgreSQL (12+)
*   Node.js (for asset building)

### Setup Steps

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/svoerman/xiam.git
    cd xiam
    ```
2.  **Install dependencies:**
    ```bash
    mix deps.get
    cd assets && npm install && cd ..
    ```
3.  **Configure your environment:** Copy `.env.example` to `.env` (if provided) or set the necessary environment variables directly. Key variables include:
    *   `DATABASE_URL`: Connection string for your PostgreSQL database (e.g., `ecto://user:pass@localhost/xiam_dev`)
    *   `SECRET_KEY_BASE`: Generate using `mix phx.gen.secret`.
    *   `JWT_SIGNING_SECRET`: A secure secret for signing API tokens (generate one).
    *   (Optional) OAuth provider keys (`GITHUB_CLIENT_ID`, `GOOGLE_CLIENT_ID`, etc.) if using social login.

    Ensure these variables are loaded into your shell environment or managed via a tool like Doppler or direnv.
4.  **Create and migrate the database:**
    ```bash
    mix ecto.create
    mix ecto.migrate
    ```
5.  **(Optional) Seed the database:** To create an initial admin user and roles:
    ```bash
    mix run priv/repo/seeds.exs
    ```
    Check the seed script output for default admin credentials.
6.  **Start the Phoenix server:**
    ```bash
    mix phx.server
    ```

XIAM should now be running at [http://localhost:4000](http://localhost:4000).

## Usage

### Core Concepts

*   **Users:** Individuals who can log in to the system.
*   **Roles:** Collections of permissions assigned to users (e.g., "Administrator", "Editor").
*   **Capabilities:** Specific permissions or actions that can be performed (e.g., `manage_users`, `edit_content`). Roles are composed of multiple capabilities.
*   **Products:** (If applicable) A way to group capabilities, often relating to different parts of an application or different services.

### Web Interface

*   **Registration/Login:** Users can register via the "Register" link or log in via the "Login" link on the homepage.
*   **Admin Panel:** Accessible at `/admin` (for users with the appropriate role/capability). This panel allows management of:
    *   Users (Assigning roles, enabling/disabling MFA)
    *   Roles & Capabilities (Creating, editing, deleting roles and capabilities, assigning capabilities to roles)
    *   Products (If applicable, managing products and their associated capabilities)
    *   Entity Access (Fine-grained permissions for specific resources, if implemented)

### API

XIAM provides a RESTful API for programmatic interaction. Authentication is handled via JWT (JSON Web Tokens). Obtain a token via the `/api/auth/login` endpoint using user credentials. Include the token in the `Authorization: Bearer <token>` header for subsequent requests.

API documentation is available via Swagger UI at [/api/docs](/api/docs).

### Configuration

Most runtime configuration, especially for production, is handled via environment variables loaded in `config/runtime.exs`. Key settings include database connection, secret keys, and external service integrations (like mailers or OAuth providers).

Default application configuration and Pow settings can be found in `config/config.exs`. Security-related settings like password complexity and account lockout are configured in `config/runtime.exs` for the production environment.

## Development

### Running Tests

Execute the test suite using:
```bash
mix test
```
