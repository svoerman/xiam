// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "../node_modules/phoenix_html"
import {Socket} from "../node_modules/phoenix"
import {LiveSocket} from "../node_modules/phoenix_live_view"
import topbar from "../vendor/topbar"
import Hooks from "./hooks/index"

// Theme handling functions
const getThemePreference = () => {
  if (typeof localStorage !== 'undefined' && localStorage.getItem('theme')) {
    return localStorage.getItem('theme');
  }
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
};

const setTheme = (theme) => {
  const root = window.document.documentElement;
  root.classList.remove('light', 'dark');
  root.classList.add(theme);
  localStorage.setItem('theme', theme);
};

// Initialize theme on page load
const theme = getThemePreference();
setTheme(theme);

// Add hook for handling confirmation dialogs
Hooks.ConfirmDialog = {
  mounted() {
    this.el.addEventListener('click', (e) => {
      const confirmMsg = this.el.getAttribute('data-confirm');
      if (confirmMsg && !window.confirm(confirmMsg)) {
        e.preventDefault();
      }
    });
  }
};

Hooks.ThemeToggle = {
  mounted() {
    this.el.addEventListener('click', () => {
      const current = getThemePreference();
      const newTheme = current === 'dark' ? 'light' : 'dark';
      setTheme(newTheme);
    });
  }
};

// Create a hook for debugging form submissions in Admin
Hooks.AdminFormDebug = {
  mounted() {
    console.log('AdminFormDebug hook mounted on', this.el);
    
    // Add a submit event listener directly to the form
    this.el.addEventListener('submit', (e) => {
      console.log('Form submit event triggered via hook', {
        event: e,
        form: this.el,
        eventPrevented: e.defaultPrevented,
        phxSubmit: this.el.getAttribute('phx-submit')
      });
    });
  }
};

// Add hook for auto-hiding flash messages after 7 seconds
Hooks.Flash = {
  mounted() {
    // Don't auto-hide connection error messages
    if (this.el.id === "client-error" || this.el.id === "server-error") {
      return;
    }
    
    console.log('Flash hook mounted on', this.el);
    
    // Set timeout to remove the flash after 7 seconds
    setTimeout(() => {
      // Add fade out effect
      this.el.style.opacity = '0';
      
      // Remove the element after fade animation completes
      setTimeout(() => {
        this.el.remove();
      }, 300); // Allow time for fade out animation
    }, 7000);
  }
};

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  hooks: Hooks,
  params: {_csrf_token: csrfToken}
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
window.liveSocket = liveSocket

// Add debugging for form submission
document.addEventListener('submit', (e) => {
  const form = e.target;
  console.log('Form submission detected', {
    form: form,
    hasPhxSubmit: form.hasAttribute('phx-submit'),
    phxSubmitValue: form.getAttribute('phx-submit'),
    action: form.action,
    method: form.method,
    id: form.id
  });
  
  // If this is a LiveView form (with phx-submit), let's verify it's properly configured
  if (form.hasAttribute('phx-submit')) {
    // Log more details about the form
    console.log('LiveView form details:', {
      formId: form.id,
      inputs: Array.from(form.elements).map(el => ({ 
        name: el.name, 
        value: el.value,
        type: el.type 
      })),
      submitter: e.submitter,
      target: form.getAttribute('phx-target')
    });
  }
});

// Add global listener for all phx: events to diagnose communication issues
window.addEventListener('phx:event', (e) => {
  console.log('PhoenixLiveView event triggered:', e.detail);
});

// Also add global handler for modals created by LiveView
window.addEventListener('phx:js-exec', ({detail}) => {
  console.log('LiveView JS exec', detail);
  
  // Handle modal operations
  if (detail.to === 'modal' && detail.attr === 'show') {
    console.log('Modal should be shown');
  }
});

// Add global event listeners to debug LiveView events
window.addEventListener("phx:click", e => {
  console.log("LiveView click event", e);
});

window.addEventListener("phx:page-loading-start", info => console.log("Loading start:", info));
window.addEventListener("phx:page-loading-stop", info => console.log("Loading stop:", info));

