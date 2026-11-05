import { Controller } from "@hotwired/stimulus"

const MAX_BYTES = 20 * 1024 * 1024

export default class extends Controller {
  static targets = ["input", "status"]
  static values = { invalidType: String, invalidSize: String, uploading: String }

  submit() {
    const file = this.inputTarget.files[0]
    if (!file) return

    if (!file.name.toLowerCase().endsWith(".xlsx")) {
      this.showError(this.invalidTypeValue)
      this.inputTarget.value = ""
      return
    }

    if (file.size < 1 || file.size > MAX_BYTES) {
      this.showError(this.invalidSizeValue)
      this.inputTarget.value = ""
      return
    }

    this.statusTarget.dataset.error = "false"
    this.statusTarget.textContent = this.uploadingValue.replace("%{filename}", file.name)
    this.element.requestSubmit()
  }

  showError(message) {
    this.statusTarget.dataset.error = "true"
    this.statusTarget.textContent = message
  }
}
