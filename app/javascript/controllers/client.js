import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    let searchParams = new URLSearchParams(window.location.search);
    if (searchParams.has('session_id')) {
      const session_id = searchParams.get('session_id');
      const el = document.getElementById('session-id');
      if (el) el.setAttribute('value', session_id);
    }
  }
}