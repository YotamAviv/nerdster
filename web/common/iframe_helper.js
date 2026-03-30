/**
 * iframe_helper.js
 * Helper utilities for constructing Nerdster Flutter app iframe URLs.
 *
 * ## Local development
 *
 * Two servers are needed: one for Nerdster, one for OneOfUs.
 * Fixed dev ports are used throughout so that iframe URLs stay consistent
 * regardless of which server is currently serving the page.
 *
 * Start servers from each project root:
 *
 * From the Nerdster project root:
 *   - flutter build web --base-href /app/
 *   - (restructure build output so app is under build/web/app/)
 *   - python3 -m http.server 8765 --directory build/web
 *
 * From the OneOfUs project root:
 *   - python3 -m http.server 8766 --directory web
 *
 * Then open:
 *   Nerdster:  http://localhost:8765/app?fire=emulator
 *   OneOfUs:   http://localhost:8766/index.html?fire=emulator
 */

(function (global) {
  /** Fixed dev port for the Nerdster Flutter app. */
  const NERDSTER_DEV_PORT = 8765;

  /** Fixed dev port for the OneOfUs static site. */
  const ONEOFUS_DEV_PORT = 8766;

  const NERDSTER_PROD_ORIGIN = "https://nerdster.org";

  /** Path where the Nerdster Flutter app is served (prod and dev). */
  const NERDSTER_APP_PATH = "/app";

  /**
   * Returns true if running on a local dev host (localhost or IP address).
   */
  function isDev() {
    const h = window.location.hostname;
    return h === "localhost" || h === "127.0.0.1" || /^\d+\.\d+\.\d+\.\d+$/.test(h);
  }

  /**
   * Returns the origin of the Nerdster Flutter app.
   * Always http://localhost:8765 in dev, https://nerdster.org in prod.
   */
  function getNerdsterOrigin() {
    return isDev()
      ? `http://localhost:${NERDSTER_DEV_PORT}`
      : NERDSTER_PROD_ORIGIN;
  }

  /**
   * Constructs an iframe URL for the Nerdster Flutter app.
   * Preserves ?fire=emulator (and other query params) from the current page,
   * and appends any additional params passed in.
   *
   * @param {Object} params - Extra key-value pairs to append as query parameters.
   * @returns {string} The fully constructed URL.
   */
  function constructUrl(params = {}) {
    const base = getNerdsterOrigin();

    // Inherit query params from this window (or parent if in a nested iframe)
    let search = window.location.search;
    if (!search && window.parent !== window) {
      try {
        search = window.parent.location.search;
      } catch (e) {
        console.debug("IframeHelper: cannot access parent location", e);
      }
    }

    let url = search
      ? `${base}${NERDSTER_APP_PATH}${search}`
      : `${base}${NERDSTER_APP_PATH}`;

    const extra = Object.entries(params)
      .filter(([, v]) => v !== undefined && v !== null)
      .map(([k, v]) => `${k}=${encodeURIComponent(v)}`);

    if (extra.length > 0) {
      url += (url.includes("?") ? "&" : "?") + extra.join("&");
    }

    return url;
  }

  global.IframeHelper = { constructUrl, getNerdsterOrigin, isDev };
})(window);
