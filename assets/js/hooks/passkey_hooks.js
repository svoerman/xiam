/**
 * Phoenix LiveView Hooks for Passkey functionality
 */
import passkey from "../passkey";

const PasskeyHooks = {
  // Hook for passkey registration
  PasskeyRegistration: {
    mounted() {
      // Listen for the custom event to trigger registration
      this.handleEvent("trigger_passkey_registration", ({ name }) => {
        this.registerPasskey(name);
      });
    },

    // Register a new passkey
    async registerPasskey(friendlyName) {
      try {
        // Check if WebAuthn is supported
        if (!passkey.isWebAuthnSupported()) {
          this.pushEvent("passkey_error", { message: "WebAuthn is not supported in this browser" });
          return;
        }

        // Register the passkey
        const result = await passkey.registerPasskey(friendlyName);
        
        if (result.success) {
          // Notify the server of success
          this.pushEvent("passkey_registered", { name: friendlyName });
        } else {
          this.pushEvent("passkey_error", { message: result.error || "Unknown error" });
        }
      } catch (error) {
        console.error("Passkey registration error:", error);
        this.pushEvent("passkey_error", { message: error.message || "Failed to register passkey" });
      }
    }
  },

  // Hook for passkey authentication
  PasskeyAuthentication: {
    mounted() {
      this.el.addEventListener("click", () => {
        const email = this.el.dataset.email || "";
        this.authenticateWithPasskey(email);
      });
    },

    // Authenticate using a passkey
    async authenticateWithPasskey(email) {
      try {
        // Check if WebAuthn is supported
        if (!passkey.isWebAuthnSupported()) {
          this.pushEvent("passkey_error", { message: "WebAuthn is not supported in this browser" });
          return;
        }

        // Show loading state
        this.pushEvent("passkey_auth_started", {});
        console.log("Starting passkey authentication with email:", email || "[empty for usernameless]");

        // Authenticate with passkey
        const result = await passkey.authenticateWithPasskey(email);
        console.log("Authentication result:", result);
        
        if (result.success && result.token) {
          // Store the token
          localStorage.setItem("auth_token", result.token);
          console.log("Authentication successful!");
          
          // Handle redirection
          if (result.redirect_to) {
            console.log("Redirecting to:", result.redirect_to);
            window.location.href = result.redirect_to;
          } else if (this.el.dataset.redirect) {
            console.log("Redirecting to data-redirect:", this.el.dataset.redirect);
            window.location.href = this.el.dataset.redirect;
          } else {
            console.log("No redirect, notifying through event");
            this.pushEvent("passkey_authenticated", { user: result.user });
          }
        } else {
          console.error("Authentication failed:", result.error || "Unknown error");
          this.pushEvent("passkey_error", { message: result.error || "Authentication failed" });
        }
      } catch (error) {
        console.error("Passkey authentication error:", error);
        this.pushEvent("passkey_error", { message: error.message || "Failed to authenticate with passkey" });
      }
    }
  },

  // Hook for passkey management
  PasskeyManagement: {
    mounted() {
      // Load the list of passkeys
      this.loadPasskeys();

      // Listen for refresh event
      this.handleEvent("refresh_passkeys", () => {
        this.loadPasskeys();
      });

      // Listen for delete event
      this.handleEvent("delete_passkey", ({ id }) => {
        this.deletePasskey(id);
      });
    },

    // Load the list of passkeys
    async loadPasskeys() {
      try {
        const passkeys = await passkey.listPasskeys();
        this.pushEvent("passkeys_loaded", { passkeys });
      } catch (error) {
        console.error("Load passkeys error:", error);
        this.pushEvent("passkey_error", { message: error.message || "Failed to load passkeys" });
      }
    },

    // Delete a passkey
    async deletePasskey(id) {
      try {
        const result = await passkey.deletePasskey(id);
        
        if (result.success) {
          this.pushEvent("passkey_deleted", { id });
          this.loadPasskeys(); // Refresh the list
        } else {
          this.pushEvent("passkey_error", { message: result.error || "Failed to delete passkey" });
        }
      } catch (error) {
        console.error("Delete passkey error:", error);
        this.pushEvent("passkey_error", { message: error.message || "Failed to delete passkey" });
      }
    }
  }
};

export default PasskeyHooks;
