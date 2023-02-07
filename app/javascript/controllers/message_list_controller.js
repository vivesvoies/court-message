import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="message-list"
export default class extends Controller {
  get scrolledDownOffset() {
    return this.element.scrollHeight - this.element.offsetHeight;
  }
  get browserSupportsAnchoring() {
    return getComputedStyle(document.body).overflowAnchor !== undefined;
  }
  
  connect() {
    this.scrollDown();
    if (!this.browserSupportsAnchoring) {
      this.observe();
    }
  }
  
  scrollDown() {
    this.element.scrollTo({ top: this.scrolledDownOffset });
  }
  
  observe() {
    const observer = new MutationObserver(this.scrollDown.bind(this));
    observer.observe(this.element, { childList: true });
  }
  
  event(event) {
    console.log(event.type, event.target, event);
  }
}
