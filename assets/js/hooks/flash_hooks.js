/**
 * Flash message hooks
 * Controls the behavior of flash messages in the application
 */

const FlashHooks = {
  Flash: {
    mounted() {
      // Don't auto-hide connection error messages
      if (this.el.id === "client-error" || this.el.id === "server-error") {
        return
      }

      // Set timeout to remove the flash after 7 seconds
      setTimeout(() => {
        // Add fade out effect
        this.el.style.opacity = '0'
        
        // Remove the element after fade animation completes
        setTimeout(() => {
          this.el.remove()
        }, 300) // Allow time for fade out animation
      }, 7000)
    }
  }
};

export default FlashHooks;
