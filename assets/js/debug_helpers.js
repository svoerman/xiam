// Debug helpers for Phoenix LiveView forms
console.log("Debug helpers loaded with enhanced form tracking");

// Set up global listeners for form submissions
document.addEventListener('DOMContentLoaded', () => {
  console.log("Setting up form debug listeners");
  
  // Listen for all form submissions
  document.addEventListener('submit', (e) => {
    const form = e.target;
    console.log('Form submission detected', {
      form: form,
      hasPhxSubmit: form.hasAttribute('phx-submit'),
      phxSubmitValue: form.getAttribute('phx-submit'),
      action: form.action,
      method: form.method,
      id: form.id,
      defaultPrevented: e.defaultPrevented,
      bubbles: e.bubbles,
      cancelable: e.cancelable,
    });
    
    // If this is a LiveView form, log more details
    if (form.hasAttribute('phx-submit')) {
      console.log('LiveView form details:', {
        formId: form.id,
        inputs: Array.from(form.elements).map(el => ({ 
          name: el.name, 
          value: el.value,
          type: el.type 
        })),
        submitter: e.submitter,
        phxEvents: Object.keys(form).filter(key => key.startsWith('__phx')),
        hooks: !!form._phxHookPending
      });
    }
  }, true); // Use capturing to ensure we catch the event before anything else
  
  // Listen for all phx events
  window.addEventListener('phx:event', (e) => {
    console.log('Phoenix LiveView event triggered:', e.detail);
  });
  
  // Add specific capture for LiveView form events
  window.addEventListener('phx:submit', (e) => {
    console.log('Phoenix LiveView phx:submit event captured:', e.detail);
  });
  
  // Add liveSocket debug event listener
  window.addEventListener('phx:page-loading-start', (e) => {
    console.log('Page loading start:', e.detail);
  });
  
  window.addEventListener('phx:page-loading-stop', (e) => {
    console.log('Page loading stop:', e.detail);
  });
  
  // Add a click handler for the add role button
  const addRoleButton = document.getElementById('add-role-button');
  if (addRoleButton) {
    console.log("Found Add Role button, adding debug listener");
    addRoleButton.addEventListener('click', (e) => {
      console.log("Add Role button clicked", e);
    });
  }
  
  // Observe DOM changes to detect when the modal appears
  const observer = new MutationObserver((mutations) => {
    mutations.forEach((mutation) => {
      if (mutation.addedNodes.length) {
        // Check for the role form being added to the DOM
        const roleForm = document.getElementById('role-form');
        if (roleForm) {
          console.log("Role form detected in DOM", roleForm);
          
          // Add a direct event listener to the form
          roleForm.addEventListener('submit', (e) => {
            console.log("Direct form submit event on role form", {
              event: e,
              defaultPrevented: e.defaultPrevented,
              target: e.target,
              currentTarget: e.currentTarget,
              formData: Object.fromEntries(new FormData(roleForm).entries())
            });
            
            // Log all form elements for debugging
            console.log("Form elements:", Array.from(roleForm.elements).map(el => ({
              id: el.id,
              name: el.name,
              value: el.value,
              type: el.type,
              disabled: el.disabled
            })));
            
            // Check if LiveView is handling this form properly
            if (!e.defaultPrevented && roleForm.hasAttribute('phx-submit')) {
              console.warn("WARNING: LiveView did not prevent default on form submission, which may indicate a problem with event binding");
            }
          });
        }
      }
    });
  });
  
  // Start observing the document with the configured parameters
  observer.observe(document.body, { childList: true, subtree: true });
});

// Export the AdminFormDebug hook for LiveView
window.AdminFormDebug = {
  mounted() {
    console.log("AdminFormDebug hook mounted on", this.el.id);
    
    // Store original form submit for tracking
    const originalSubmit = this.el.submit;
    this.el.submit = function() {
      console.log("Form.submit() was called directly", this);
      return originalSubmit.apply(this, arguments);
    };
    
    // Add direct event listener to the form element
    this.el.addEventListener('submit', (event) => {
      console.log("Form submit event captured by hook event listener", {
        form: this.el,
        formId: this.el.id,
        phxSubmit: this.el.getAttribute('phx-submit'),
        defaultPrevented: event.defaultPrevented,
        formData: Object.fromEntries(new FormData(this.el).entries())
      });
    });
    
    // Track when the form is submitted via LiveView
    this.handleEvent("submit", (payload) => {
      console.log("LiveView submit event received in hook", payload);
    });
    
    // Add more LiveView event handlers
    this.handleEvent("phx:form-submit-start", (payload) => {
      console.log("LiveView form submit start event", payload);
    });
    
    this.handleEvent("phx:form-submit-end", (payload) => {
      console.log("LiveView form submit end event", payload);
    });
  },
  
  // Called before form is submitted via LiveView
  submitting() {
    console.log("AdminFormDebug hook submitting form", {
      form: this.el,
      formData: Object.fromEntries(new FormData(this.el).entries())
    });
    return true; // Allow the submission to continue
  },
  
  // Called after form is submitted via LiveView
  submitted() {
    console.log("AdminFormDebug hook form submitted successfully");
  },
  
  // Called when the hook is being removed
  destroyed() {
    console.log("AdminFormDebug hook being destroyed", this.el.id);
  }
};
