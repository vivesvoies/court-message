import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["password", "passwordConfirmation", "currentPassword"];

  toggle() {
    const isPasswordVisible = this.passwordTarget.type === "text";
    const newPasswordType = isPasswordVisible ? "password" : "text";

    this.togglePasswordVisibility(newPasswordType);
  }

  togglePasswordVisibility(type) {
    this.passwordTarget.type = type;
    this.passwordConfirmationTarget.type = type;
    if (this.hasCurrentPasswordTarget) {
      this.currentPasswordTarget.type = type;
    }
  }
}
