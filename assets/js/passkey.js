/**
 * Passkey (WebAuthn) functionality for XIAM
 * This module provides functions for registering and using passkeys.
 */

/**
 * Base64URL encode an ArrayBuffer
 * @param {ArrayBuffer} buffer - The buffer to encode
 * @returns {string} - Base64URL encoded string
 */
function base64UrlEncode(buffer) {
  const base64 = window.btoa(String.fromCharCode(...new Uint8Array(buffer)));
  return base64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

/**
 * Base64URL decode to ArrayBuffer
 * @param {string} base64Url - Base64URL encoded string
 * @returns {ArrayBuffer} - Decoded ArrayBuffer
 */
function base64UrlDecode(base64Url) {
  const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
  const binaryString = window.atob(base64);
  const bytes = new Uint8Array(binaryString.length);
  for (let i = 0; i < binaryString.length; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }
  return bytes.buffer;
}

/**
 * Prepare options for WebAuthn API by converting base64url strings to ArrayBuffers
 * @param {Object} options - Options from the server
 * @returns {Object} - Prepared options for WebAuthn API
 */
function preparePublicKeyOptions(options) {
  // Convert challenge from base64url to ArrayBuffer
  options.challenge = base64UrlDecode(options.challenge);

  // Convert user.id if present
  if (options.user && options.user.id) {
    options.user.id = base64UrlDecode(options.user.id);
  }

  // Convert excludeCredentials if present
  if (options.excludeCredentials) {
    options.excludeCredentials = options.excludeCredentials.map(credential => {
      return {
        ...credential,
        id: base64UrlDecode(credential.id)
      };
    });
  }

  // Convert allowCredentials if present
  if (options.allowCredentials) {
    options.allowCredentials = options.allowCredentials.map(credential => {
      return {
        ...credential,
        id: base64UrlDecode(credential.id)
      };
    });
  }

  return options;
}

/**
 * Prepare credential response for sending to server
 * @param {PublicKeyCredential} credential - Credential from WebAuthn API
 * @returns {Object} - Prepared credential for server
 */
function prepareCredentialForServer(credential) {
  const response = {};

  // Add id and type
  response.id = credential.id;
  response.type = credential.type;

  // Handle attestation response (for registration)
  if (credential.response.attestationObject) {
    response.response = {
      clientDataJSON: base64UrlEncode(credential.response.clientDataJSON),
      attestationObject: base64UrlEncode(credential.response.attestationObject)
    };
  }
  // Handle assertion response (for authentication)
  else if (credential.response.authenticatorData) {
    response.response = {
      clientDataJSON: base64UrlEncode(credential.response.clientDataJSON),
      authenticatorData: base64UrlEncode(credential.response.authenticatorData),
      signature: base64UrlEncode(credential.response.signature),
      userHandle: credential.response.userHandle ? 
        base64UrlEncode(credential.response.userHandle) : null
    };
  }

  // Add clientExtensionResults if present
  if (credential.clientExtensionResults) {
    response.clientExtensionResults = credential.clientExtensionResults;
  }

  return response;
}

/**
 * Check if WebAuthn is supported in this browser
 * @returns {boolean} - Whether WebAuthn is supported
 */
function isWebAuthnSupported() {
  return window.PublicKeyCredential !== undefined;
}

/**
 * Register a new passkey
 * @param {string} friendlyName - User-friendly name for the passkey
 * @returns {Promise<Object>} - Result of registration
 */
async function registerPasskey(friendlyName) {
  if (!isWebAuthnSupported()) {
    throw new Error('WebAuthn is not supported in this browser');
  }

  try {
    // Get registration options from server
    const optionsResponse = await fetch('/api/passkeys/registration_options', {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${getAuthToken()}`
      }
    });

    if (!optionsResponse.ok) {
      const error = await optionsResponse.json();
      throw new Error(error.error || 'Failed to get registration options');
    }

    const optionsData = await optionsResponse.json();
    
    // Prepare options for WebAuthn API
    const publicKeyOptions = preparePublicKeyOptions(optionsData.options);

    // Create credential
    const credential = await navigator.credentials.create({
      publicKey: publicKeyOptions
    });

    // Prepare credential for server
    const credentialForServer = prepareCredentialForServer(credential);

    // Send credential to server
    const registerResponse = await fetch('/api/passkeys/register', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${getAuthToken()}`
      },
      body: JSON.stringify({
        attestation: credentialForServer,
        friendly_name: friendlyName
      })
    });

    if (!registerResponse.ok) {
      const error = await registerResponse.json();
      throw new Error(error.error || 'Failed to register passkey');
    }

    return registerResponse.json();
  } catch (error) {
    console.error('Passkey registration error:', error);
    throw error;
  }
}

/**
 * Authenticate using a passkey
 * @param {string} email - User's email address (optional for usernameless auth)
 * @returns {Promise<Object>} - Authentication result including JWT token
 */
async function authenticateWithPasskey(email) {
  if (!isWebAuthnSupported()) {
    throw new Error('WebAuthn is not supported in this browser');
  }

  try {
    console.log('Starting passkey authentication process');
    
    // Get authentication options from server
    // Pass email if provided, empty for usernameless authentication
    const url = email ? 
      `/api/auth/passkey/options?email=${encodeURIComponent(email)}` : 
      '/api/auth/passkey/options';
      
    console.log('Fetching auth options from:', url);
    const optionsResponse = await fetch(url, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json'
      },
      credentials: 'same-origin' // Include cookies
    });

    if (!optionsResponse.ok) {
      const error = await optionsResponse.json();
      throw new Error(error.error || 'Failed to get authentication options');
    }

    // Get the options data from the response
    const optionsData = await optionsResponse.json();
    console.log('Auth options received:', optionsData);
    
    // Handle different response formats - older format used .options
    // newer format has the options directly in the response
    const rawOptions = optionsData.options || optionsData;
    
    // Prepare options for WebAuthn API
    const publicKeyOptions = preparePublicKeyOptions(rawOptions);
    console.log('Prepared public key options:', publicKeyOptions);

    // Request user to select a passkey
    console.log('Requesting credential from browser...');
    const credential = await navigator.credentials.get({
      publicKey: publicKeyOptions,
      mediation: 'optional' // Let the browser decide how to prompt the user
    });
    console.log('Credential received:', credential);

    // Prepare credential for server
    const credentialForServer = prepareCredentialForServer(credential);
    console.log('Sending assertion to server:', credentialForServer);

    // Send credential to server
    const authResponse = await fetch('/api/auth/passkey', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      credentials: 'same-origin', // Include cookies
      body: JSON.stringify({
        assertion: credentialForServer
      })
    });

    if (!authResponse.ok) {
      const error = await authResponse.json();
      throw new Error(error.error || 'Failed to authenticate with passkey');
    }

    const authResult = await authResponse.json();
    console.log('Authentication successful:', authResult);
    
    // Store the JWT token
    if (authResult.token) {
      localStorage.setItem('auth_token', authResult.token);
    }

    return authResult;
  } catch (error) {
    console.error('Passkey authentication error:', error);
    throw error;
  }
}

/**
 * Get a list of registered passkeys for the current user
 * @returns {Promise<Array>} - List of passkeys
 */
async function listPasskeys() {
  try {
    const response = await fetch('/api/passkeys', {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${getAuthToken()}`
      }
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || 'Failed to list passkeys');
    }

    const data = await response.json();
    return data.passkeys;
  } catch (error) {
    console.error('List passkeys error:', error);
    throw error;
  }
}

/**
 * Delete a passkey
 * @param {string} id - ID of the passkey to delete
 * @returns {Promise<Object>} - Result of deletion
 */
async function deletePasskey(id) {
  try {
    const response = await fetch(`/api/passkeys/${id}`, {
      method: 'DELETE',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${getAuthToken()}`
      }
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || 'Failed to delete passkey');
    }

    return response.json();
  } catch (error) {
    console.error('Delete passkey error:', error);
    throw error;
  }
}

/**
 * Get the authentication token from local storage or from the session cookie
 * @returns {string} - Authentication token
 */
function getAuthToken() {
  // First try to get from localStorage (for API calls)
  const token = localStorage.getItem('auth_token');
  if (token) return token;
  
  // If not found, we might be in a server-rendered context where cookies are used
  // The LiveView will handle the authentication in this case
  return null;
}

// Export the functions
export default {
  isWebAuthnSupported,
  registerPasskey,
  authenticateWithPasskey,
  listPasskeys,
  deletePasskey
};
