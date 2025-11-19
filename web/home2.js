// Lightweight interactive behavior for home2.html
(()=>{
  const d = document;

  // Elements (optional — page may omit some)
  const modal = d.getElementById('modal');
  const modalContent = d.getElementById('modalContent');
  const modalClose = d.getElementById('modalClose');

  const overlay = d.getElementById('overlay');
  const detailContainer = d.getElementById('detail-container');
  
  // ensure modal content can receive focus (for accessibility and to avoid
  // focus-driven scrolling). We'll make it programmatically focusable.
  if(modalContent) modalContent.tabIndex = -1;

  // (QR/status controls removed; demo now uses the embedded iframe controls)


  // Modal and box behavior delegated to shared `boxes.js` module.
  // `boxes.js` implements modal open/close, scroll-lock and focus restoration
  // and wires `.box` elements. Initialize it here to ensure unified behavior.
  window.boxes.init();

  // Detail block: show content in the modal overlay so it appears above the iframe
  function openDetail(content){
    openModal(content);
  }
  function closeDetail(){
    closeModal();
  }

  // Boxes are wired via the shared `boxes` module (initialized above).

  // Theme handling removed — site is fixed to a single Eclipse-style palette.

  // Header nav dropdown (top-right)
  const navToggle = d.getElementById('navDropdownToggle');
  const navMenu = d.getElementById('navDropdownMenu');
  function closeNav(){ navToggle.setAttribute('aria-expanded','false'); navMenu.hidden = true; }
  function openNav(){ navToggle.setAttribute('aria-expanded','true'); navMenu.hidden = false; }
  navToggle.addEventListener('click', e=>{
    const expanded = navToggle.getAttribute('aria-expanded') === 'true';
    if(expanded) closeNav(); else openNav();
  });
  // close nav when clicking outside
  document.addEventListener('click', e=>{
    const dd = d.getElementById('navDropdown');
    if(!dd) return;
    if(!dd.contains(e.target)) closeNav();
  });
  // allow opening via ArrowDown and focus first item
  navToggle.addEventListener('keydown', e=>{
  if(e.key==='ArrowDown'){ e.preventDefault(); openNav(); const first = navMenu.querySelector('[role="menuitem"]'); if(first) first.focus(); }
  });

  // Keyboard
  document.addEventListener('keydown', e=>{
    if(e.key==='Escape'){ closeDetail(); closeModal(); closeNav(); }
  });

  // postMessage hook (optional)
  window.addEventListener('message', ev=>{
    strictGuard(()=>{
      const m = typeof ev.data === 'string' ? JSON.parse(ev.data) : ev.data;
      if(m?.action==='open' && m.detailId){ const ref = document.getElementById(m.detailId); if(ref) openDetail(ref.innerHTML); }
    }, 'home2.js');
  });

  // Support postMessage requests that reference a detail id moved inside a box.
  // If the id lookup fails, try to find a box with data-detail === detailId
  // and open its colocated template content.
  window.addEventListener('message', ev=>{
    strictGuard(()=>{
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
    }, 'home2.js');
  });

})();
