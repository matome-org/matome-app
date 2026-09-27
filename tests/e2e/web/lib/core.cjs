// FakeCore's control API (/__e2e/): reset, seed, break, hold answers back,
// and read back what Core holds. Control calls are never counted or faulted.
"use strict";

const crypto = require("node:crypto");

class Core {
  constructor(stack) {
    this.stack = stack;
  }

  async call(method, route, body) {
    const reply = await fetch(`${this.stack.coreUrl}/__e2e/${route}`, {
      method,
      headers: body ? { "content-type": "application/json" } : {},
      body: body ? JSON.stringify(body) : undefined,
    });
    if (!reply.ok)
      throw new Error(`fakecore ${route}: ${reply.status} ${await reply.text()}`);
    return reply.json();
  }

  reset() { return this.call("POST", "reset"); }
  seed(spec) { return this.call("POST", "seed", spec); }
  confirmEmail(email) { return this.call("POST", "confirm-email", { email }); }
  resetPassword(email, password) { return this.call("POST", "reset-password", { email, password }); }
  acceptInvitation(email, name) { return this.call("POST", "accept-invitation", { email, name }); }
  // {path (regex), method?, count?, mode?: status|drop|expire|hold, status?, error?}
  // A hold answers as usual but parks the answer until release().
  fail(rule) { return this.call("POST", "fail", rule); }
  release() { return this.call("POST", "release"); }
  state() { return this.call("GET", "state"); }

  async document(title) {
    return (await this.state()).documents.find((doc) => doc.title === title);
  }

  async folder(name) {
    return (await this.state()).folders.find((folder) => folder.name === name);
  }
}

function sha256(bytes) {
  return crypto.createHash("sha256").update(bytes).digest("hex");
}

module.exports = { Core, sha256 };
