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

Hooks.PersistUserSelect = {
  mounted() {
    // Store the current value on mount
    this.value = this.el.value
    
    // Listen for changes to the select and store them
    this.el.addEventListener("change", e => {
      this.value = e.target.value
    })
    
    // Handle the init event from the server
    this.handleEvent("init-user-select", () => {
      // Nothing to do here, just setting up the hook
    })
  },
  
  updated() {
    // If the element's value is different from our stored value
    // and our stored value is not empty, restore it
    if (this.el.value !== this.value && this.value) {
      this.el.value = this.value
      
      // If necessary, trigger a change event for LiveView to catch
      const event = new Event("change", { bubbles: true })
      this.el.dispatchEvent(event)
    }
  }
}

export default Hooks 