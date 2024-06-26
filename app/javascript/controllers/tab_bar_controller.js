import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tab-bar"
export default class extends Controller {
  static targets = [ "tab" ];
  static outlets = [ "viewer" ];
  static classes = [ "activeTab" ];

  selectTab(e) {
    this.setActiveTab({ currentTarget: e.currentTarget });
    this.viewerOutlet.tabBarChange(e.params);
  }

  setActiveTab({ currentTarget, id }) {
    let target = (currentTarget) ? currentTarget : this.tabTargets.find(tab => tab.id === `tab-btn-${id}`);
    this.tabTargets.forEach(tab => tab.classList.remove(this.activeTabClass));

    if (!target) {
      return;
    }

    target.classList.add(this.activeTabClass);
  }
}
