import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="auto-remove"
export default class extends Controller {
  connect() {
    this.element.addEventListener("animationend", this.remove.bind(this));
    this.element.addEventListener("click", this.remove.bind(this));
  }
  remove() {
    this.element.remove();
  }
}
