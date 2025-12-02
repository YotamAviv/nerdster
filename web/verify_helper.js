const VerifyHelper = {
  iframeId: 'flutterApp',

  getIframe: function() {
    return document.getElementById(this.iframeId);
  },

  updateVerify: function(key) {
    const iframe = this.getIframe();
    const data = demoData[key];
    iframe.contentWindow.postMessage(
      { 
        verify: JSON.stringify(data, null, 2),
        verifyImmediately: "true"
      },
      "*"
    );
  },

  setupListeners: function(ids) {
    if (!Array.isArray(ids)) {
      throw new Error("VerifyHelper.setupListeners: Parameter must be an array of IDs.");
    }

    for (const id of ids) {
      const el = document.getElementById(id);
      if (el) {
        el.addEventListener("click", (e) => {
          e.preventDefault();
          this.updateVerify(id);
        });
      } else {
        console.warn(`Element with id '${id}' not found.`);
      }
    }
  }
};
