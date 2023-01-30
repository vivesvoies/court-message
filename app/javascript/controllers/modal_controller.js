import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="modal"
export default class extends Controller {
  connect() {}
  open() {
    this.element.classList.add("fr-modal--opened");
  }
  close() {
    this.element.remove();
  }
  clicked(event) {
    if (event.target == this.element) {
      this.close();
    }
  }
  submitted(event) {
    if (event.detail.success) {
      this.close();
    }
  }
}
