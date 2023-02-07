import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="conversation-detail"
export default class extends Controller {
  static targets = ["contactFrame"];

  toggleContact(event) {
    this.element.classList.toggle("ConversationDetail--contact-visible");
  }
}
