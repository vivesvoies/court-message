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
    if (this.selection && this.selection === target.id) {
      this.select(target);
    }
  }

  deselect() {
    const selected = this.element.querySelectorAll(`.${this.itemClass}`);
    selected.forEach(conv => conv.classList.remove(this.activeClass));
  }

  select(target) {
    JSON. stringify(target)
    this.deselect();
    target.classList.add(this.activeClass);
    this.selection = target.id;
  }

  toggleReadStatus(event) {
    const target = event.target.closest(`.${this.itemClass}`);
    const isUnread = target.classList.contains(this.unreadClass);
    const newStatus = isUnread ? "read" : "unread";
  
    this.updateReadStatus(target, newStatus);
  
    // TODO: Change for toggle switch
    event.target.textContent = isUnread ? "Unread" : "Read";
  }

  updateReadStatus(target, status) {
    const url = target.dataset.conversationStatusUrl;
  
    if (!target.classList.contains(this.unreadClass) && status === "read") {
      return;
    }
    fetch(url, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name=\"csrf-token\"]").content
      },
      body: JSON.stringify({ status })
    })
      .then(() => {
        if (status === "read") {
          this.select(target);
          sessionStorage.setItem('activeConversation', target.id);
        } else {
          this.deselect();
          sessionStorage.removeItem('activeConversation');
        }
      })
      .catch((error) => console.error("Error:", error));
      console.log("session : " + sessionStorage.getItem('activeConversation'))
  }
}
