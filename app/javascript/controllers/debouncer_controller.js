import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="debouncer"
export default class extends Controller {
  debounceSubmit() {
    console.log("ping")
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      console.log("pong")
      this.element.requestSubmit()
    }, 200)
  }
}
