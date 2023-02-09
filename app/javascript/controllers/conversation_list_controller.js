import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="conversation-list"
export default class extends Controller {
  static targets = ["conversation"];
  static classes = ["item", "active"];
  connect() {
  }
  activate(event) {
    const target = event.target.closest(`.${this.itemClass}`);
    const selected = this.element.querySelectorAll(`.${this.itemClass}`);
    
    selected.forEach(conv => conv.classList.remove(this.activeClass));
    target.classList.add(this.activeClass);
  }
}
