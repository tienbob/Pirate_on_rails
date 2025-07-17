import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "submitButton", "cardElement", "cardErrors"]
  static values = { publicKey: String }

  connect() {
    this.stripe = Stripe(this.publicKeyValue)
    this.elements = this.stripe.elements()
    this.card = this.elements.create('card')
    this.card.mount(this.cardElementTarget)
    this.formTarget.addEventListener('submit', this.handleSubmit.bind(this))
  }

  handleSubmit(event) {
    event.preventDefault()
    this.submitButtonTarget.disabled = true
    this.stripe.createToken(this.card).then(result => {
      if (result.error) {
        this.cardErrorsTarget.textContent = result.error.message
        this.submitButtonTarget.disabled = false
      } else {
        const hiddenInput = document.createElement('input')
        hiddenInput.type = 'hidden'
        hiddenInput.name = 'stripeToken'
        hiddenInput.value = result.token.id
        this.formTarget.appendChild(hiddenInput)
        this.formTarget.submit()
      }
    })
  }
}
