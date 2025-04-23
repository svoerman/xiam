defmodule XIAMWeb.PasskeyLoginComponent do
  @moduledoc """
  Component for passkey login and registration functionality.
  """
  use XIAMWeb, :html

  def passkey_login_button(assigns) do
    ~H"""
    <div class="mt-6">
      <div class="relative">
        <div class="absolute inset-0 flex items-center">
          <div class="w-full border-t border-gray-300 dark:border-gray-700"></div>
        </div>
        <div class="relative flex justify-center text-sm">
          <span class="px-2 bg-white dark:bg-gray-900 text-gray-500 dark:text-gray-400">Or continue with</span>
        </div>
      </div>

      <div class="mt-6 space-y-3">
        <button
          type="button"
          id="passkey-login-button"
          phx-hook="PasskeyAuthentication"
          data-email={@email}
          data-redirect={@redirect_path}
          class="w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-primary-600 hover:bg-primary-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500 dark:bg-primary-700 dark:hover:bg-primary-600"
        >
          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2" viewBox="0 0 20 20" fill="currentColor">
            <path fill-rule="evenodd" d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z" clip-rule="evenodd" />
          </svg>
          Sign in with Passkey
        </button>

        <div class="text-center text-sm text-gray-500 dark:text-gray-400">
          <span>Don't have a passkey yet? </span>
          <a href="/account" class="font-medium text-primary-600 hover:text-primary-500 dark:text-primary-400 dark:hover:text-primary-300">
            Set up in account settings
          </a>
          <span> after login</span>
        </div>
      </div>
    </div>
    """
  end
end
