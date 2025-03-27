const Hooks = {}

Hooks.Flash = {
  mounted() {
    // Don't auto-hide connection error messages
    if (this.el.id === "client-error" || this.el.id === "server-error") {
      return
    }

    // Set timeout to remove the flash after 10 seconds
    setTimeout(() => {
      // Add fade out effect
      this.el.style.opacity = '0'
      
      // Remove the element after fade animation completes
      setTimeout(() => {
        this.el.remove()
      }, 300) // Allow time for fade out animation
    }, 10000)
  }
}

export default Hooks 