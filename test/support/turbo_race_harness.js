// Injected into the page by system tests (see turbo_race_harness.rb).
//
// Turbo Stream messages (over Action Cable) and fetch() responses reach the
// page in whatever order the network gives. The harness can hold either kind
// and release it later, so a test can replay each ordering on purpose instead
// of hoping the timing shows it. It also logs fetch() requests and counts the
// ones still running.
//
// Turbo's own navigation keeps a reference to the original fetch, so only the
// app's fetch() calls (Stimulus controllers) go through here.
(() => {
  if (window.raceHarness) return;

  const heldStreams = [];
  const heldResponses = [];
  const requests = [];
  const streamLog = [];
  let holdingStreams = false;
  let holdingResponses = null;
  let running = 0;

  // A stream source dispatches each message as a "message" event on itself.
  // Capturing on the document runs first, and can stop it before Turbo sees it.
  document.addEventListener("message", (event) => {
    if (!(event.target instanceof Element) || event.target.localName !== "turbo-cable-stream-source") return;

    streamLog.push(summarize(event.data));
    if (!holdingStreams) return;

    event.stopImmediatePropagation();
    heldStreams.push(event.data);
  }, true);

  // "action target first-element-classes" for each stream action in a message.
  function summarize(html) {
    const template = document.createElement("template");
    template.innerHTML = html;
    return [...template.content.querySelectorAll("turbo-stream")].map((stream) => {
      const element = stream.querySelector("template")?.content.firstElementChild;
      return [stream.getAttribute("action"), stream.getAttribute("target"), element?.className].filter(Boolean).join(" ");
    }).join(" + ");
  }

  const originalFetch = window.fetch.bind(window);
  window.fetch = (input, init = {}) => {
    const url = typeof input === "string" ? input : input.url;
    requests.push({ method: (init.method || "GET").toUpperCase(), url, body: init.body || null });
    running++;

    const response = originalFetch(input, init);
    const delivered = holdingResponses && holdingResponses.test(url)
      ? new Promise((resolve, reject) => heldResponses.push(() => response.then(resolve, reject)))
      : response;
    return delivered.finally(() => running--);
  };

  window.raceHarness = {
    holdStreams() { holdingStreams = true; },
    releaseStreams() {
      holdingStreams = false;
      for (const html of heldStreams.splice(0)) window.Turbo.renderStreamMessage(html);
    },
    heldStreams() { return heldStreams.length; },

    holdResponses(pattern) { holdingResponses = new RegExp(pattern); },
    releaseResponses() {
      holdingResponses = null;
      for (const release of heldResponses.splice(0)) release();
    },
    heldResponses() { return heldResponses.length; },

    streamLog() { return streamLog; },
    requests() { return requests; },
    running() { return running; }
  };
})();
