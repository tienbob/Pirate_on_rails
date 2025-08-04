import { Controller } from "@hotwired/stimulus"

// Lazy loading controller for images and videos
export default class extends Controller {
  static targets = ["image", "video", "placeholder"]
  static values = { 
    threshold: { type: Number, default: 0.1 },
    rootMargin: { type: String, default: "50px" }
  }

  connect() {
    this.setupIntersectionObserver()
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }

  setupIntersectionObserver() {
    this.observer = new IntersectionObserver(
      (entries) => this.handleIntersection(entries),
      {
        threshold: this.thresholdValue,
        rootMargin: this.rootMarginValue
      }
    )

    // Observe all lazy-loadable elements
    this.imageTargets.forEach(img => this.observer.observe(img))
    this.videoTargets.forEach(video => this.observer.observe(video))
  }

  handleIntersection(entries) {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        this.loadElement(entry.target)
        this.observer.unobserve(entry.target)
      }
    })
  }

  loadElement(element) {
    if (element.tagName === 'IMG') {
      this.loadImage(element)
    } else if (element.tagName === 'VIDEO') {
      this.loadVideo(element)
    }
  }

  loadImage(img) {
    const src = img.dataset.src
    if (src) {
      img.src = src
      img.removeAttribute('data-src')
      
      // Show image with fade-in effect
      img.addEventListener('load', () => {
        img.classList.add('loaded')
        this.hidePlaceholder(img)
      })
      
      img.addEventListener('error', () => {
        img.classList.add('error')
        this.showErrorPlaceholder(img)
      })
    }
  }

  loadVideo(video) {
    const src = video.dataset.src
    if (src) {
      video.src = src
      video.removeAttribute('data-src')
      video.load()
      
      video.addEventListener('loadeddata', () => {
        video.classList.add('loaded')
        this.hidePlaceholder(video)
      })
    }
  }

  hidePlaceholder(element) {
    const placeholder = element.previousElementSibling
    if (placeholder && placeholder.classList.contains('loading-placeholder')) {
      placeholder.style.display = 'none'
    }
  }

  showErrorPlaceholder(element) {
    const placeholder = element.previousElementSibling
    if (placeholder && placeholder.classList.contains('loading-placeholder')) {
      placeholder.innerHTML = '<i class="fas fa-exclamation-triangle"></i> Failed to load'
      placeholder.classList.add('error')
    }
  }
}
