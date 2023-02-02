import { Controller } from "@hotwired/stimulus"
import { count } from "sms-length";

// Connects to data-controller="message-box"
export default class extends Controller {
  static targets = ["textarea", "counter"];
  connect() {
  }
  keydown(event) {
    switch (event.key) {
      case "Enter":
        if (!event.altKey && !event.shiftKey) {
          event.preventDefault();
          this.submit();
          return;
        }
        break;
    }
  }
  input(event) {
    const stats = count(this.textareaTarget.value);
    this.counterTarget.innerHTML = this._formatStats(stats);
  }
  reset() {
    this.element.reset();
  }
  submit(event) {
    if (this.textareaTarget.value.trim() === "") {
      event.preventDefault();
    }
  }
  
  _formatStats({ length, remaining, inCurrentMessage, messages, characterPerMessage }) {
    if (messages === 0) {
      return null;
    }
    if (messages === 1) {
      return `${length}/${characterPerMessage}`;
    }
    return `${length}/${characterPerMessage}, ${messages} SMS`;
  }
}
