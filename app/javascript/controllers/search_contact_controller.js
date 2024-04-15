import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="list-remote"
export default class extends Controller {
  static outlets = ["conversation-list"];

  deselect() {
    this.conversationListOutlet.deselect();
  }
}
