import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="conversation-list"
export default class extends Controller {
  static targets = ["conversation"];
  static classes = ["item", "active", "unread", "link"];

  initialize() {
    const selectedId = sessionStorage.getItem('activeConversation');
    if (selectedId) {
      const selected = this.conversationTargets.find(conv => conv.id === selectedId);
      if (selected) {
        this.select(selected);
      }
    }
  }

  activate(event) {
    const target = event.target.closest(`.${this.itemClass}`);
    this.select(target);
    sessionStorage.setItem('activeConversation', target.id);
  }

  conversationTargetConnected(target) {
    if (this.selection === target.id) {
      this.select(target);
      if (target.classList.contains(this.unreadClass)) {
        this.markAsRead(target);
      }
    }
  }

  deselect() {
    const selected = this.element.querySelectorAll(`.${this.itemClass}`);
    selected.forEach(conv => conv.classList.remove(this.activeClass));
  }

  select(target) {
    this.deselect();
    target.classList.add(this.activeClass);
    this.selection = target.id;
  }

  markAsRead(target) {
    if (!target.classList.contains(this.unreadClass)) {
      return;
    }
    const url = target.dataset.conversationStatusUrl;
    fetch(url, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name=\"csrf-token\"]").content
      },
      body: JSON.stringify({ status: "read" })
    })
    .catch((error) => console.error("Error:", error));
  }
}
