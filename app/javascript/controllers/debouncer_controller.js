import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="debouncer"
export default class extends Controller {
  debounceSubmit() {
    clearTimeout(this.timeout);
    this.timeout = setTimeout(() => {
      this.element.requestSubmit();
    }, 200);
  }
}
