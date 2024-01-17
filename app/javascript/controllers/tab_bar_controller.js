import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tab-bar"
export default class extends Controller {
  static targets = [ "tab" ];
  static outlets = [ "viewer" ];
  static classes = [ "activeTab" ];

  selectTab(e) {
    this.tabTargets.forEach(tab => tab.classList.remove(this.activeTabClass));
    e.currentTarget.classList.add(this.activeTabClass);

    this.viewerOutlet.tabBarChange(e.params);
  }
}
