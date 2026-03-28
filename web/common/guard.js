/*
 * guard.js
 * Minimal strict guards for fail-fast behavior.
 * Exposes:
 *  - window.guard.strictGuard(fn, label)
 *  - window.guard.strictGuardAsync(fn, label)
 * Also attaches top-level helpers: window.strictGuard, window.strictGuardAsync
 *
 * strictGuard(fn, label) will call fn() synchronously; if fn throws, the
 * error is logged with the provided label and then rethrown.
 *
 * strictGuardAsync(fn, label) will call and await fn(); if the returned
 * promise rejects, the error is logged with the provided label and then
 * rethrown.
 */
(function(){
  'use strict';

  function _log(label, err){
    if(label) console.error('[strictGuard]', label, err);
    else console.error('[strictGuard]', err);
  }

  function strictGuard(fn, label){
    try{
      return fn();
    }catch(e){
      _log(label, e);
      throw e;
    }
  }

  async function strictGuardAsync(fn, label){
    try{
      return await fn();
    }catch(e){
      _log(label, e);
      throw e;
    }
  }

  window.guard = { strictGuard, strictGuardAsync };
  window.strictGuard = strictGuard;
  window.strictGuardAsync = strictGuardAsync;

})();
