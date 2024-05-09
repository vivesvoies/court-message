import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="navigation"
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
    target.classList.add(this.activeTabClass);
  }
}
