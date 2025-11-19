// Lightweight interactive behavior for home2.html
(()=>{
  const d = document;

  // Elements (optional — page may omit some)
  const modal = d.getElementById('modal');
  const modalContent = d.getElementById('modalContent');
  const modalClose = d.getElementById('modalClose');

  const drawer = d.getElementById('app-drawer');
  const drawerOpen = d.getElementById('drawer-open');
  const drawerClose = d.getElementById('drawer-close');
  const overlay = d.getElementById('overlay');
  const detailContainer = d.getElementById('detail-container');
  const themeSelect = d.getElementById('theme-select');
  // ensure modal content can receive focus (for accessibility and to avoid
  // focus-driven scrolling). We'll make it programmatically focusable.
  if(modalContent) modalContent.tabIndex = -1;

  // (QR/status controls removed; demo now uses the embedded iframe controls)


  // Modal handling — use the hidden attribute so CSS respects visibility rules
  let _prevActive = null;
  let _scrollY = 0;
  function _lockScroll(){
    try{
      // Freeze the viewport by fixing the body at the current scroll Y.
      // This prevents the scrollbar disappearing from nudging content.
      _scrollY = window.scrollY || window.pageYOffset || 0;
      document.body.style.position = 'fixed';
      document.body.style.top = '-' + _scrollY + 'px';
      document.body.style.left = '0';
      document.body.style.right = '0';
      document.body.style.width = '100%';
    }catch(e){}
  }
  function _unlockScroll(){
    try{
      // restore original flow and scroll position
      document.body.style.position = '';
      document.body.style.top = '';
      document.body.style.left = '';
      document.body.style.right = '';
      document.body.style.width = '';
      window.scrollTo(0, _scrollY || 0);
      _scrollY = 0;
    }catch(e){}
  }

  function openModal(html){
    if(!modal || !modalContent) return
    _prevActive = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    modalContent.innerHTML = html;
    modal.hidden = false;
    modal.setAttribute('aria-hidden','false');
    if(overlay) overlay.hidden = false;
    _lockScroll();
    // focus without scrolling the page (preventScroll where supported)
    try{ modalContent.focus({preventScroll:true}); }catch(e){ try{ modalContent.focus(); }catch(e){} }
  }
  function closeModal(){
    if(!modal) return
    modal.hidden = true;
    modal.setAttribute('aria-hidden','true');
    if(overlay) overlay.hidden = true;
    _unlockScroll();
    // restore previous focus if possible
    try{ _prevActive && _prevActive.focus && _prevActive.focus({preventScroll:true}); }catch(e){ try{ _prevActive && _prevActive.focus && _prevActive.focus(); }catch(e){} }
    _prevActive = null;
    // remove visual selection from any boxes when modal closes
    try{ document.querySelectorAll('.box.selected').forEach(b=>b.classList.remove('selected')); }catch(e){}
  }
  modalClose?.addEventListener('click', closeModal);
  modal?.addEventListener('click', e=>{ if(e.target===modal) closeModal(); });

  // Drawer handling
  function showDrawer(){ if(drawer) drawer.hidden = false; if(overlay) overlay.hidden = false }
  function hideDrawer(){ if(drawer) drawer.hidden = true; if(overlay) overlay.hidden = true }
  drawerOpen?.addEventListener('click', showDrawer);
  drawerClose?.addEventListener('click', hideDrawer);

  overlay?.addEventListener('click', ()=>{ hideDrawer(); closeDetail(); closeModal(); });

  // Detail block: show content in the modal overlay so it appears above the iframe
  function openDetail(content){
    openModal(content);
  }
  function closeDetail(){
    closeModal();
  }

  // Make the boxes themselves interactive: click or keyboard (Enter/Space)
  d.querySelectorAll('.box[data-detail]').forEach(box=>{
    // ensure keyboard focusability (role/tabindex added in HTML)
    box.addEventListener('click', e=>{
      // ignore clicks that originate from an interactive element inside the box
      const target = e.target;
      if(target && (target.tagName==='A' || target.tagName==='BUTTON' || target.closest('a') || target.closest('button'))) return;
      const id = box.dataset.detail;
      const ref = id && d.getElementById(id);
      if(!ref) return;
      // mark this box as selected and clear others
      try{ document.querySelectorAll('.box.selected').forEach(b=>b.classList.remove('selected')); }catch(e){}
      try{ box.classList.add('selected'); }catch(e){}
      openDetail(ref.innerHTML);
    });
    box.addEventListener('keydown', e=>{
      if(e.key === 'Enter' || e.key === ' ' || e.key === 'Spacebar'){
        e.preventDefault();
        box.click();
      }
    });
  });

  // Theme handling removed — site is fixed to a single Eclipse-style palette.

  // Keyboard
  document.addEventListener('keydown', e=>{
    if(e.key==='Escape'){ hideDrawer(); closeDetail(); closeModal(); }
  });

  // postMessage hook (optional)
  window.addEventListener('message', ev=>{
    try{
      const m = typeof ev.data === 'string' ? JSON.parse(ev.data) : ev.data;
  if(m?.action==='open' && m.detailId){ const ref = document.getElementById(m.detailId); if(ref) openDetail(ref.innerHTML); }
  if(m?.action==='theme' && m.theme) setTheme(m.theme);
    }catch(e){}
  });

})();
