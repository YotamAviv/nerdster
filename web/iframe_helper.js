/**
 * iframe_helper.js
 * Helper utilities for constructing iframe URLs with environment detection.
 */
(function (global) {
  function getBaseUrl() {
    const hostname = window.location.hostname;
    // Detect dev environment: localhost, 127.0.0.1, or IP address pattern
    const isDev =
      hostname === "localhost" ||
      hostname === "127.0.0.1" ||
      /^\d+\.\d+\.\d+\.\d+$/.test(hostname);

    return isDev ? window.location.origin : "https://nerdster.org";
  }

  /**
   * Constructs the full URL for the Flutter app iframe.
   * - Detects environment (dev vs prod) to choose origin.
   * - Preserves existing query parameters from the parent page (e.g. ?fire=emulator).
   * - Appends additional parameters passed in the `params` object.
   *
   * @param {Object} params - Key-value pairs to append as query parameters.
   * @returns {string} The fully constructed URL.
   */
  function constructUrl(params = {}) {
    const base = getBaseUrl();
    let currentSearch = window.location.search; // e.g. ?fire=emulator

    // If no search params on current window, try the parent window (for nested iframes like crypto.html)
    if (!currentSearch && window.parent !== window) {
      try {
        currentSearch = window.parent.location.search;
      } catch (e) {
        // Ignore cross-origin access errors
        console.debug("IframeHelper: Cannot access parent location", e);
      }
    }

    // Start with base + current search params
    // If currentSearch exists, it starts with '?', so just append it.
    // If not, append '/' to ensure we hit the root.
    let url = currentSearch ? `${base}${currentSearch}` : `${base}/`;

    const newParams = [];
    for (const [key, value] of Object.entries(params)) {
      if (value !== undefined && value !== null) {
        newParams.push(`${key}=${encodeURIComponent(value)}`);
      }
    }

    if (newParams.length > 0) {
      const separator = url.includes("?") ? "&" : "?";
      url += separator + newParams.join("&");
    }

    return url;
  }

  global.IframeHelper = {
    constructUrl,
  };
})(window);
