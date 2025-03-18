// Basic Phoenix HTML module stub to resolve dependency
console.log("Phoenix HTML loaded");

// Expose form functionality for Phoenix HTML forms
export function handleFormSubmit(event) {
  // Default form submission handler
  return true;
}

// Utility function to serialize form data
export function serializeForm(form) {
  const formData = new FormData(form);
  const data = {};
  
  for (let [key, value] of formData.entries()) {
    data[key] = value;
  }
  
  return data;
}

// Function to disable form elements during submission
export function disableFormElements(form) {
  const elements = form.querySelectorAll('input, button, select, textarea');
  elements.forEach(element => {
    element.disabled = true;
  });
}

// Function to enable form elements after submission
export function enableFormElements(form) {
  const elements = form.querySelectorAll('input, button, select, textarea');
  elements.forEach(element => {
    element.disabled = false;
  });
}

// Add form submit event listeners
document.addEventListener('DOMContentLoaded', () => {
  console.log("Phoenix HTML DOM ready");
});
