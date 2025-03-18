// Basic Phoenix Socket implementation
export class Socket {
  constructor(endPoint, opts = {}) {
    this.endPoint = endPoint;
    this.opts = opts;
    this.channels = [];
    this.params = opts.params || {};
    this.reconnectAfterMs = opts.reconnectAfterMs || [10, 50, 100, 150, 200, 250, 500, 1000, 2000];
    this.timeout = opts.timeout || 10000;
    this.heartbeatIntervalMs = opts.heartbeatIntervalMs || 30000;
    this.longpollerTimeout = opts.longpollerTimeout || 20000;
    this.heartbeatTimer = null;
    this.reconnectTimer = null;
    this.logger = opts.logger || console;
    this.binaryType = opts.binaryType || "arraybuffer";
    this.connCallbacks = {
      open: [],
      error: [],
      close: [],
      message: []
    };
  }

  // Connect to the server
  connect() {
    console.log("Phoenix socket connected");
    return this;
  }

  // Disconnect from the server
  disconnect() {
    console.log("Phoenix socket disconnected");
    return this;
  }

  // Log events
  log(kind, msg, data) {
    this.logger.log(`${kind}: ${msg}`, data);
  }

  // Create a new channel
  channel(topic, params = {}) {
    const channel = {
      topic,
      params,
      join: () => {
        console.log(`Joined channel: ${topic}`);
        return Promise.resolve({});
      },
      leave: () => {
        console.log(`Left channel: ${topic}`);
        return Promise.resolve({});
      },
      on: (event, callback) => {
        console.log(`Added handler for ${event} on ${topic}`);
        return channel;
      },
      push: (event, payload) => {
        console.log(`Pushed ${event} to ${topic} with payload`, payload);
        return Promise.resolve({});
      }
    };
    this.channels.push(channel);
    return channel;
  }

  // Hook into connection events
  onOpen(callback) {
    this.connCallbacks.open.push(callback);
  }

  onClose(callback) {
    this.connCallbacks.close.push(callback);
  }

  onError(callback) {
    this.connCallbacks.error.push(callback);
  }

  onMessage(callback) {
    this.connCallbacks.message.push(callback);
  }
}
