// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "../vendor/phoenix_html.js"
// Import Phoenix Socket module
import {Socket} from "../vendor/phoenix.js"
import topbar from "../vendor/topbar"

// Import Phoenix LiveView
import {LiveSocket} from "../vendor/live_view.js"

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

// Define custom hooks
let Hooks = {};

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

// Import our debug helpers and register debug hooks
import "./debug_helpers";

// Get the AdminFormDebug hook for LiveView
Hooks.AdminFormDebug = window.AdminFormDebug;


let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
// Enable debug mode for LiveView
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  hooks: Hooks,
  params: {_csrf_token: csrfToken},
  debug: true // Enable verbose debugging
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// Enable debug mode to diagnose event issues
liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

console.log('Phoenix liveSocket attached to window', window.liveSocket);

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

// Add this at the end of the file to debug any LiveView click events
console.log("Adding LiveView click debugger...");

document.addEventListener('click', (event) => {
  const element = event.target.closest('[phx-click]');
  if (element) {
    const eventName = element.getAttribute('phx-click');
    console.log('Element with phx-click detected:', {
      element: element,
      eventName: eventName,
      id: element.id,
      classList: Array.from(element.classList)
    });
  }
}, true);

// Debug all button clicks
document.addEventListener('click', (event) => {
  const button = event.target.closest('button');
  if (button) {
    console.log('Button clicked:', {
      button: button,
      id: button.id,
      text: button.textContent.trim(),
      attributes: Array.from(button.attributes).map(attr => ({ name: attr.name, value: attr.value }))
    });
  }
}, true);

console.log("LiveView click debugger added.")

