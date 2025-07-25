import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["popup", "open", "close", "form", "input", "messages"];

  connect() {
    this.openTarget.addEventListener("click", () => {
      this.popupTarget.style.display = "flex";
      this.openTarget.style.display = "none";
    });
    this.closeTarget.addEventListener("click", () => {
      this.popupTarget.style.display = "none";
      this.openTarget.style.display = "flex";
    });
    this.formTarget.addEventListener("submit", async (e) => {
      e.preventDefault();
      const msg = this.inputTarget.value.trim();
      if (msg) {
        // Show user message
        const div = document.createElement("div");
        div.textContent = msg;
        div.style.margin = "8px 0";
        div.style.textAlign = "right";
        this.messagesTarget.appendChild(div);
        this.inputTarget.value = "";
        this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight;

        // Send to backend via AJAX (Hotwire convention: fetch, not jQuery)
        const csrfToken = document.querySelector('meta[name="csrf-token"]').getAttribute('content');
        try {
          const response = await fetch("/chats", {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "X-CSRF-Token": csrfToken
            },
            body: JSON.stringify({ message: msg })
          });
          if (response.ok) {
            const data = await response.json();
            if (data.response) {
              const aiDiv = document.createElement("div");
              aiDiv.textContent = data.response;
              aiDiv.style.margin = "8px 0";
              aiDiv.style.textAlign = "left";
              aiDiv.style.color = "#007bff";
              this.messagesTarget.appendChild(aiDiv);
              this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight;
            }
          } else {
            // Error handling
            const errDiv = document.createElement("div");
            errDiv.textContent = "Error: Could not get response.";
            errDiv.style.margin = "8px 0";
            errDiv.style.textAlign = "left";
            errDiv.style.color = "#dc3545";
            this.messagesTarget.appendChild(errDiv);
            this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight;
          }
        } catch (err) {
          const errDiv = document.createElement("div");
          errDiv.textContent = "Network error.";
          errDiv.style.margin = "8px 0";
          errDiv.style.textAlign = "left";
          errDiv.style.color = "#dc3545";
          this.messagesTarget.appendChild(errDiv);
          this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight;
        }
      }
    });
  }
}
