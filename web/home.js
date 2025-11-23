// Lightweight interactive behavior for home.html
(async () => {
  const d = document;

  // --- Iframe init + demo-button wiring (formerly embed.js) ---
  const iframe = document.getElementById('flutterApp');
  if (iframe) {
    // Use IframeHelper to set the src, preserving query params and handling environment
    if (window.IframeHelper) {
      iframe.src = window.IframeHelper.constructUrl({});
      console.info('home.js: iframe src set to', iframe.src);
    } else {
      // Fallback if IframeHelper is missing
      const origin = location.origin;
      const search = location.search || '';
      iframe.src = search ? `${origin}${search}` : `${origin}/`;
    }

    try {
      const response = await fetch('/data/simpsonsDemo.json');
      const demoKeys = await response.json();

      const aviv = document.getElementById('load-aviv');
      if (aviv) {
        aviv.addEventListener('click', function (ev) {
          ev.preventDefault();
          const AVIV = { crv: 'Ed25519', kty: 'OKP', x: 'Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo' };
          iframe.contentWindow.postMessage({ identity: AVIV }, '*');
        });
      }

      const lisa = document.getElementById('load-lisa');
      if (lisa) {
        lisa.addEventListener('click', function (ev) {
          ev.preventDefault();
          iframe.contentWindow.postMessage({ identity: demoKeys.lisa }, '*');
        });
      }

      const bart = document.getElementById('load-bart');
      if (bart) {
        bart.addEventListener('click', function (ev) {
          ev.preventDefault();
          iframe.contentWindow.postMessage({ identity: demoKeys.bart }, '*');
        });
      }
    } catch (e) {
      console.warn('home.js: Failed to load demo keys or wire buttons', e);
    }
  }

  // --- Modal and interaction logic ---

  const modalContent = d.getElementById('modalContent');
  
  // ensure modal content can receive focus (for accessibility and to avoid
  // focus-driven scrolling). We'll make it programmatically focusable.
  if(modalContent) modalContent.tabIndex = -1;

  // (QR/status controls removed; demo now uses the embedded iframe controls)


  // Modal and box behavior delegated to shared `boxes.js` module.
  // `boxes.js` implements modal open/close, scroll-lock and focus restoration
  // and wires `.box` elements. Initialize it here to ensure unified behavior.
  if (window.boxes) window.boxes.init();

  // Detail block: show content in the modal overlay so it appears above the iframe
  function openDetail(content){
    if (window.boxes) window.boxes.openModal(content);
  }
  function closeDetail(){
    if (window.boxes) window.boxes.closeModal();
  }


  // Keyboard
  document.addEventListener('keydown', e=>{
    if(e.key==='Escape'){ closeDetail(); }
  });

  // postMessage hook (optional)
  window.addEventListener('message', ev=>{
    const handler = () => {
      const m = typeof ev.data === 'string' ? JSON.parse(ev.data) : ev.data;
      if(m?.action==='open' && m.detailId){
        let ref = document.getElementById(m.detailId);
        if(ref) return openDetail(ref.innerHTML);
        // find a box that declares that detail id
        const box = document.querySelector('.box[data-detail="' + m.detailId + '"]');
        if(box){
          const tmpl = box.querySelector && box.querySelector('template.box-detail');
          if(tmpl && tmpl.content){
            const frag = tmpl.content.cloneNode(true);
            const container = document.createElement('div');
            container.appendChild(frag);
            return openDetail(container.innerHTML);
          }
        }
      }
    };

    if (typeof strictGuard === 'function') {
      strictGuard(handler, 'home.js');
    } else {
      handler();
    }
  });

})();
