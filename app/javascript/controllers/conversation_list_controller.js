import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="conversation-list"
export default class extends Controller {
  static targets = ["conversation"];
  static classes = ["item", "active", "unread"];

  initialize() {
    const selected = this.conversationTargets.filter(conv => conv.classList.contains(this.activeClass));
    if (selected.length > 0) {
      this.selection = selected[0].id;
    }
  }

  activate(event) {
    const target = event.target.closest(`.${this.itemClass}`);
    this.select(target);
  }

  conversationTargetConnected(target) {
    if (this.selection === target.id) {
      this.select(target);
      if (target.classList.contains(this.unreadClass)) {
        this.markAsRead(target);
      }
    }
  }

  select(target) {
    const selected = this.element.querySelectorAll(`.${this.itemClass}`);
    
    selected.forEach(conv => conv.classList.remove(this.activeClass));
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
