import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="viewer"
export default class extends Controller {
  static targets = [ "conversationIndicator" ];

  showDetailView() {
    this.element.classList.add("Viewer--detail-visible");
  }
  hideDetailView() {
    this.element.classList.remove("Viewer--detail-visible");
  }

  conversationIndicatorTargetConnected(e) {
    this.showDetailView();
  }
  conversationIndicatorTargetDisconnected(e) {
    this.hideDetailView()
  }
}
