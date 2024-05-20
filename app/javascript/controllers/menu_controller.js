import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="menu"
export default class extends Controller {
  static outlets = [ "viewer" ];

  selectItem(e) {
    this.viewerOutlet.menuVisit(e.params.label);
  }

}
