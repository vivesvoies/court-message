import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="viewer"
export default class extends Controller {
  static targets = [ "conversationIndicator" ];
  static outlets = [ "conversation-list", "tab-bar" ];

  connect() {
    this.element.addEventListener("tabbarchange", this.tabBarChange.bind(this));
  }

  menuOpen() {
    this.tabBarOutlet.setActiveTab({ id: "home" });
  }

  menuClose() {
    this.tabBarOutlet.setActiveTab({ id: "conversations" });
  }

  tabBarChange(params) {
    this.element.className = this.element.className.replace(/\bViewer--detail-\S+/g, "");
    this.element.className = this.element.className.replace(/\bViewer--tab-\S+/g, "");
    this.element.classList.add(`Viewer--tab-${params.label}`);

    // if (params.label === "conversations") {
    //   this.conversationListOutlet.reselect();
    // }
  }

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
    this.hideDetailView();
  }
}
