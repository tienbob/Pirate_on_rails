import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "password", "passwordConfirmation", "email"]

  connect() {
    this.element.addEventListener('input', this.validate.bind(this))
  }

  validate() {
    this.clearErrors()
    this.validateRequired()
    this.validateEmail()
    this.validatePasswordMatch()
  }

  clearErrors() {
    this.inputTargets.forEach(input => {
      input.classList.remove('is-invalid')
      const feedback = input.nextElementSibling
      if (feedback && feedback.classList.contains('invalid-feedback')) {
        feedback.remove()
      }
    })
  }

  validateRequired() {
    this.inputTargets.forEach(input => {
      if (input.required && !input.value.trim()) {
        this.showError(input, 'This field is required.')
      }
    })
  }

  validateEmail() {
    if (this.hasEmailTarget) {
      const email = this.emailTarget
      if (email.value && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email.value)) {
        this.showError(email, 'Please enter a valid email address.')
      }
    }
  }

  validatePasswordMatch() {
    if (this.hasPasswordTarget && this.hasPasswordConfirmationTarget) {
      const password = this.passwordTarget
      const confirmation = this.passwordConfirmationTarget
      if (password.value || confirmation.value) {
        if (password.value !== confirmation.value) {
          this.showError(confirmation, 'Passwords do not match.')
        }
      }
    }
  }

  showError(input, message) {
    input.classList.add('is-invalid')
    if (!input.nextElementSibling || !input.nextElementSibling.classList.contains('invalid-feedback')) {
      const feedback = document.createElement('div')
      feedback.className = 'invalid-feedback'
      feedback.innerText = message
      input.parentNode.insertBefore(feedback, input.nextSibling)
    }
  }
}
