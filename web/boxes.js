/*
 * boxes.js
 * Shared boxes + modal behavior used by multiple pages.
 * Exposes a global `window.boxes` with init/openModal/closeModal helpers.
 * Auto-initializes on load for pages that just include the script.
 */
/* Clean module content - single self-contained module */
(function(){
  const d = document;
  let _elements = null;
  let _inited = false;
  let _prevActive = null;
  let _scrollY = 0;

  function ensureModal() {
    let overlay = d.getElementById('overlay');
    let modal = d.getElementById('modal');
    if (!overlay) {
      overlay = d.createElement('div');
      overlay.id = 'overlay';
      overlay.className = 'overlay';
      overlay.setAttribute('aria-hidden','true');
      d.body.appendChild(overlay);
    }
    if (!modal) {
      modal = d.createElement('div');
      modal.id = 'modal';
      modal.className = 'modal';
      modal.setAttribute('aria-hidden','true');
      modal.innerHTML = '<div class="modal-inner" role="dialog" aria-modal="true">'
        + '<button id="modalClose" class="modal-close" aria-label="Close">✕</button>'
        + '<div id="modalContent"></div>'
        + '</div>';
      d.body.appendChild(modal);
    }
    return { overlay, modal, modalContent: d.getElementById('modalContent'), modalClose: d.getElementById('modalClose') };
  }

  function _lockScroll(){
    try{
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
    if(!_elements) _elements = ensureModal();
    const { modal, modalContent, overlay } = _elements;
    if(!modal || !modalContent) return;
    _prevActive = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    modalContent.innerHTML = html;
    modal.setAttribute('aria-hidden','false');
    modal.hidden = false;
    if(overlay) { overlay.setAttribute('aria-hidden','false'); overlay.hidden = false; }
    _lockScroll();
    try{ modalContent.focus({preventScroll:true}); }catch(e){ try{ modalContent.focus(); }catch(e){} }
    try{ setTimeout(()=>{ const c = d.getElementById('modalClose'); if(c) c.focus(); }, 30); }catch(e){}
  }

  function closeModal(){
    if(!_elements) _elements = ensureModal();
    const { modal, modalContent, overlay } = _elements;
    if(!modal) return;
    try{ d.querySelectorAll('.box.selected').forEach(b=>b.classList.remove('selected')); }catch(e){}
    modal.setAttribute('aria-hidden','true');
    modal.hidden = true;
    if(overlay){ overlay.setAttribute('aria-hidden','true'); overlay.hidden = true; }
    _unlockScroll();
    if(modalContent) modalContent.innerHTML = '';
    try{
      if(_prevActive && _prevActive instanceof HTMLElement){
        const insideBox = _prevActive.closest && _prevActive.closest('.box');
        if(!insideBox){ try{ _prevActive.focus({preventScroll:true}); }catch(e){ try{ _prevActive.focus(); }catch(e){} } }
        else {
          const container = d.querySelector('.container');
          if(container){ const hadTab = container.hasAttribute('tabindex'); if(!hadTab) container.setAttribute('tabindex','-1'); try{ container.focus({preventScroll:true}); }catch(e){ try{ container.focus(); }catch(e){} } if(!hadTab) container.removeAttribute('tabindex'); }
        }
      }
    }catch(e){}
    _prevActive = null;
  }

  function _wireOverlayAndEsc(){
    if(!_elements) _elements = ensureModal();
    const { overlay, modalClose, modal } = _elements;
    if(overlay) overlay.addEventListener('click', closeModal);
    if(modalClose) modalClose.addEventListener('click', closeModal);
    if(modal) modal.addEventListener('click', e => { if(e.target === modal) closeModal(); });
    d.addEventListener('keydown', e => { if(e.key === 'Escape') closeModal(); });
  }

  function init(){
    if(_inited) return;
    _elements = ensureModal();
    _wireOverlayAndEsc();

    d.querySelectorAll('.box').forEach(box => {
      const onClick = (e) => {
        const target = e.target;
        if(target && (target.tagName === 'A' || target.tagName === 'BUTTON' || target.closest('a') || target.closest('button'))) return;
        const tmpl = box.querySelector && box.querySelector('template.box-detail');
        let content = null;
        if(tmpl && tmpl.content){ const frag = tmpl.content.cloneNode(true); const c = document.createElement('div'); c.appendChild(frag); content = c.innerHTML; }
        if(!content) return;
        try{ d.querySelectorAll('.box.selected').forEach(b=>b.classList.remove('selected')); }catch(e){}
        try{ box.classList.add('selected'); }catch(e){}
        openModal(content);
      };
      box.addEventListener('click', onClick);
      box.addEventListener('keydown', e => { if(e.key === 'Enter' || e.key === ' ' || e.key === 'Spacebar'){ e.preventDefault(); onClick(e); } });
    });

    _inited = true;
  }

  window.boxes = { init, openModal, closeModal };

  try{ document.readyState === 'loading' ? document.addEventListener('DOMContentLoaded', init) : init(); }catch(e){ init(); }

})();

