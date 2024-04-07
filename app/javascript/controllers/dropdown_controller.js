import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static classes = ["item"];

  initialize() {
    this.element.addEventListener("click", this.click.bind(this));
  }

  click(event) {
    // Check if the click happens inside the dropdown.
    // As the backdrop is pseudo-element of the dropdown, we need to filter out `this.element` itself.
    const isItemClick = this.element.contains(event.target) && this.element !== event.target;

    if (!isItemClick) {
      this.close();
    }
  }

  close() {
    this.element.removeAttribute("open");
  }
}