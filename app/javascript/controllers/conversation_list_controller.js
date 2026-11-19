import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="conversation-list"
//
// Read status, as agents see it:
// - opening a conversation marks it read (ConversationsController#show);
// - a new message in the open conversation marks it read again, since the
//   agent has it in front of them;
// - any other unread rendering (an agent marked it unread, here or elsewhere)
//   is left alone.
// Items carry the id of their last message: a different id means a new
// message. Inferring a new message from "unread" alone sent a manual unread
// straight back to read, as soon as its own update reached the list.
export default class extends Controller {
  static targets = ["conversation"];
  static classes = ["item", "active", "unread", "read", "link"];

  initialize() {
    // Status requests per conversation id, chained so that they reach the
    // server one at a time and in the order asked (a quick double toggle).
    this.statusRequests = new Map();

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
    // Deduplicate: if a conversation was already prepended by a broadcast,
    // remove the older copy (keep the newly connected target at the top)
    const duplicates = this.element.querySelectorAll(`#${target.id}`);
    for (const dup of duplicates) {
      if (dup !== target) dup.remove();
    }

    if (this.selection === target.id) {
      const newMessage = target.dataset.lastMessageId !== this.selectedLastMessageId;
      this.select(target);
      if (newMessage && this.isUnread(target)) {
        this.updateStatus(target, "read");
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
    this.selectedLastMessageId = target.dataset.lastMessageId;
  }

  toggleRead(event) {
    event.preventDefault();
    const target = event.target.closest(`.${this.itemClass}`);
    this.updateStatus(target, this.isUnread(target) ? "read" : "unread");
  }

  isUnread(target) {
    return target.classList.contains(this.unreadClass);
  }

  // Shows the new status at once, then sends it after the requests already
  // queued for this conversation. The server's broadcast confirms it later.
  updateStatus(target, status) {
    const id = target.id;
    const url = target.dataset.conversationStatusUrl;
    this.render(target, status);

    const previous = this.statusRequests.get(id) || Promise.resolve();
    const request = previous
      .then(() => this.sendStatus(url, status))
      .catch((error) => {
        console.error("Error:", error);
        // The item may have been re-rendered meanwhile: find it again.
        const current = document.getElementById(id);
        if (current) this.render(current, status === "read" ? "unread" : "read");
      });
    this.statusRequests.set(id, request);
    request.then(() => {
      if (this.statusRequests.get(id) === request) this.statusRequests.delete(id);
    });
  }

  async sendStatus(url, status) {
    const headers = { "Content-Type": "application/json" };
    // Absent where forgery protection is off (tests): the request still goes.
    const token = document.querySelector("meta[name=\"csrf-token\"]")?.content;
    if (token) headers["X-CSRF-Token"] = token;

    const response = await fetch(url, { method: "PATCH", headers, body: JSON.stringify({ status }) });
    if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
  }

  render(target, status) {
    const unread = status === "unread";
    target.classList.toggle(this.unreadClass, unread);
    target.classList.toggle(this.readClass, !unread);

    const toggle = target.querySelector("[data-read-toggle]");
    if (toggle) {
      toggle.setAttribute("aria-pressed", unread);
      toggle.title = unread ? toggle.dataset.markReadLabel : toggle.dataset.markUnreadLabel;
    }
  }
}
