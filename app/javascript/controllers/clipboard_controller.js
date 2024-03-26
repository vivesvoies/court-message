import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "source" ]

  copy() {
    const content = this.sourceTarget.innerText;
    navigator.clipboard.writeText(content);
  }
}