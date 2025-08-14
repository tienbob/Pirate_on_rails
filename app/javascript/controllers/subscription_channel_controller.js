import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

export default class extends Controller {
  connect() {
    this.subscription = consumer.subscriptions.create("SubscriptionChannel", {
      received: (data) => {
        this.showToast("Your subscription status has been updated.");
        setTimeout(() => {
          window.location.reload();
        }, 1200);
      }
    })
  }

  disconnect() {
    if (this.subscription) {
      consumer.subscriptions.remove(this.subscription)
    }
  }

  showToast(message) {
    const toast = document.createElement("div");
    toast.textContent = message;
    toast.style.position = "fixed";
    toast.style.bottom = "32px";
    toast.style.left = "50%";
    toast.style.transform = "translateX(-50%)";
    toast.style.background = "#4f46e5";
    toast.style.color = "#fff";
    toast.style.padding = "14px 32px";
    toast.style.borderRadius = "8px";
    toast.style.boxShadow = "0 2px 8px rgba(0,0,0,0.15)";
    toast.style.fontSize = "1.1rem";
    toast.style.zIndex = 9999;
    toast.style.opacity = 0.97;
    document.body.appendChild(toast);
    setTimeout(() => {
      toast.remove();
    }, 1100);
  }
}
