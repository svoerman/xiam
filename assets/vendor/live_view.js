// LiveSocket class implementation
export class LiveSocket {
  constructor(url, socket, opts = {}) {
    this.url = url;
    this.socket = socket;
    this.opts = opts;
    this.connected = false;
    this.params = opts.params || {};
    this.viewLogger = opts.viewLogger;
    this.activeElement = null;
    this.prevActive = null;
    this.silenced = false;
    this.main = null;
    this.bindingPrefix = opts.bindingPrefix || "phx-";
    this.debug = opts.debug || false;
  }

  // Connect to the LiveView Socket
  connect() {
    this.connected = true;
    console.log("LiveView socket connected");
    return this;
  }

  // Disconnect the LiveView Socket
  disconnect() {
    this.connected = false;
    console.log("LiveView socket disconnected");
    return this;
  }

  // Enable debug mode
  enableDebug() {
    this.debug = true;
    console.log("LiveView debug mode enabled");
    return this;
  }

  // Enable latency simulation for testing
  enableLatencySim(timeMs) {
    this.latency = timeMs;
    console.log(`LiveView latency simulation enabled: ${timeMs}ms`);
    return this;
  }

  // Disable latency simulation
  disableLatencySim() {
    this.latency = null;
    console.log("LiveView latency simulation disabled");
    return this;
  }
}
