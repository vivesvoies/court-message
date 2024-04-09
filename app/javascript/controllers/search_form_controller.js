import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  debounceSubmit() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.element.requestSubmit()
    }, 200)
  }
}
