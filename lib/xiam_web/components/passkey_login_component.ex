defmodule XIAMWeb.PasskeyLoginComponent do
  @moduledoc """
  Component for passkey login and registration functionality.
  """
  use XIAMWeb, :html

  def passkey_login_button(assigns) do
    ~H"""
    <div class="mt-6">
      <div class="flex items-center gap-4 my-6">
        <div class="flex-1 border-t border-border"></div>
        <span class="text-sm text-muted-foreground">Or continue with</span>
        <div class="flex-1 border-t border-border"></div>
      </div>
      <div class="space-y-3">
        <button
          type="button"
          id="passkey-login-button"
          phx-hook="PasskeyAuthentication"
          data-email={@email}
          data-redirect={@redirect_path}
          class="btn btn-primary w-full flex items-center justify-center gap-2"
        >
          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
            <path fill-rule="evenodd" d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z" clip-rule="evenodd" />
          </svg>
          Sign in with Passkey
        </button>
        <div class="text-center text-sm text-muted-foreground">
          <span>Don't have a passkey yet? </span>
          <a href="/account" class="font-medium text-primary hover:underline">
            Set up in account settings
          </a>
          <span> after login</span>
        </div>
      </div>
    </div>
    """
  end
end
