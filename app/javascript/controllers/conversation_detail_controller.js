import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="conversation-detail"
export default class extends Controller {
  static targets = ["contactFrame", "streamedMessage"];

  toggleContact(event) {
    this.element.classList.toggle("ConversationDetail--contact-visible");
  }

  streamedMessageTargetConnected(target) {
    console.log("new message", target);
  }
}
