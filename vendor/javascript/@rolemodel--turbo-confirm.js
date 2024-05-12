const dispatch=(t,e=document,{bubbles:n=true,cancelable:o=true,prefix:i="rms",detail:r}={})=>{const s=new CustomEvent(`${i}:${t}`,{bubbles:n,cancelable:o,detail:r});e.dispatchEvent(s);return!s.defaultPrevented};class TurboConfirmError extends Error{name="TurboConfirmError";static missingDialog(t,e){return new this(`No element matching dialogSelector: '${t}'`,{cause:e})}static noTurbo(){return new this('Turbo is not defined. Be sure to import "@hotwired/turbo-rails" before calling the `start()` function')}}class ConfirmationController{initialContent;#t;constructor(t){this.delegate=t;this.accept=this.accept.bind(this);this.deny=this.deny.bind(this)}showConfirm(t){this.#e();for(const[e,n]of Object.entries(t)){const t=this.element.querySelector(e);t&&n&&(t.innerHTML=n)}this.#n();this.delegate.showConfirm(this.element);return new Promise((t=>this.#t=t))}accept(){this.#t(true);this.#o()}deny(){this.#t(false);this.#o()}get acceptButtons(){return this.element.querySelectorAll(this.delegate.acceptSelector)}get denyButtons(){return this.element.querySelectorAll(this.delegate.denySelector)}get element(){return document.querySelector(this.delegate.dialogSelector)}#o(){this.#t=null;this.delegate.hideConfirm(this.element);this.#i();setTimeout(this.#r.bind(this),this.delegate.animationDuration)}#n(){this.acceptButtons.forEach((t=>t.addEventListener("click",this.accept)));this.denyButtons.forEach((t=>t.addEventListener("click",this.deny)));this.element.addEventListener("cancel",this.deny)}#i(){this.acceptButtons.forEach((t=>t.removeEventListener("click",this.accept)));this.denyButtons.forEach((t=>t.removeEventListener("click",this.deny)));this.element.removeEventListener("cancel",this.deny)}#e(){try{this.initialContent=this.element.innerHTML}catch(t){throw TurboConfirmError.missingDialog(this.delegate.dialogSelector,t)}}#r(){try{this.element.innerHTML=this.initialContent}catch{}}}class TurboConfirm{#s;#c={dialogSelector:"#confirm",activeClass:"modal--active",acceptSelector:"#confirm-accept",denySelector:".confirm-cancel",animationDuration:300,showConfirmCallback:t=>t.showModal&&t.showModal(),hideConfirmCallback:t=>t.close&&t.close(),messageSlotSelector:"#confirm-title",contentSlots:{body:{contentAttribute:"confirm-details",slotSelector:"#confirm-body"},acceptText:{contentAttribute:"confirm-button",slotSelector:"#confirm-accept"}}};constructor(t={}){for(const[e,n]of Object.entries(t))this.#c[e]=n;this.#s=new ConfirmationController(this)}
/**
   * Present a confirmation challenge to the user.
   * @public
   * @param {string} [message] - The main challenge message; Value of `data-turbo-confirm` attribute.
   * @param {HTMLFormElement} [_formElement] - (ignored) `form` element that contains the submitter.
   * @param {HTMLElement} [submitter] - button of input of type submit that triggered the form submission.
   * @returns {Promise<boolean>} - A promise that resolves to true if the user accepts the challenge or false if they deny it.
   */confirm(t,e,n){const o=this.#l(n);const i=this.#a(t,o);return this.confirmWithContent(i)}
/**
   * Present a confirmation challenge to the user.
   * @public
   * @param {Object} contentMap - A map of CSS selectors to HTML content to be inserted into the dialog.
   * @returns {Promise<boolean>} - A promise that resolves to true if the user accepts the challenge or false if they deny it.
   */confirmWithContent(t){return this.#s.showConfirm(t)}showConfirm(t){t.classList.add(this.#c.activeClass);typeof this.#c.showConfirmCallback==="function"&&this.#c.showConfirmCallback(t)}hideConfirm(t){t.classList.remove(this.#c.activeClass);typeof this.#c.hideConfirmCallback==="function"&&this.#c.hideConfirmCallback(t)}get dialogSelector(){return this.#c.dialogSelector}get acceptSelector(){return this.#c.acceptSelector}get denySelector(){return this.#c.denySelector}get animationDuration(){return this.#c.animationDuration}#a(t,e){const n={};t&&(n[this.#c.messageSlotSelector]=t);if(e)for(const t of Object.keys(this.#c.contentSlots))n[this.#h(t)]=this.#f(t,e);return n}#h(t){return this.#c.contentSlots[t].slotSelector}#f(t,e){return e.getAttribute(`data-${this.#c.contentSlots[t].contentAttribute}`)}#l(t){const e=t??document.activeElement;return e.closest("[data-turbo-confirm]")}}const start=t=>{const e=new TurboConfirm(t);if(!window.Turbo)throw TurboConfirmError.noTurbo();window.Turbo.setConfirmMethod((async(t,n,o)=>{const i=await e.confirm(t,n,o);dispatch(i?"confirm-accept":"confirm-reject",o);return i}))};var t={start:start};export{TurboConfirm,t as default};
