import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "text", "preview"]

  connect() {
    console.log('File upload controller connected')
    console.log('Element:', this.element)
    console.log('Has input target:', this.hasInputTarget)
    console.log('Has text target:', this.hasTextTarget)
    console.log('Input target:', this.inputTarget)
    console.log('Text target:', this.textTarget)
    this.setupFileInput()
  }

  setupFileInput() {
    if (this.hasInputTarget) {
      this.inputTarget.addEventListener('change', (event) => {
        this.handleFileSelection(event)
      })

      // Drag and drop support
      const container = this.element.querySelector('.file-input-container, .file-input-container-series')
      if (container) {
        container.addEventListener('dragover', (e) => {
          e.preventDefault()
          container.classList.add('drag-over')
        })

        container.addEventListener('dragleave', (e) => {
          e.preventDefault()
          container.classList.remove('drag-over')
        })

        container.addEventListener('drop', (e) => {
          e.preventDefault()
          container.classList.remove('drag-over')
          
          const files = e.dataTransfer.files
          if (files.length > 0) {
            this.inputTarget.files = files
            this.handleFileSelection({ target: { files } })
          }
        })
      }
    }
  }

  handleFileSelection(event) {
    const files = event.target.files
    if (files.length > 0) {
      const file = files[0]
      console.log('File selected:', file.name, file.size, file.type)
      this.updateFileDisplay(file)
    } else {
      console.log('No file selected')
      this.reset()
    }
  }

  updateFileDisplay(file) {
    console.log('Updating file display for:', file.name)
    
    if (this.hasTextTarget) {
      const fileName = file.name
      const fileSize = this.formatFileSize(file.size)
      const fileType = file.type
      
      console.log('Updating text target with file info')
      
      // Update the display text
      this.textTarget.innerHTML = `
        <div class="file-selected">
          <i class="fas fa-check-circle mb-2" style="font-size: 2rem; color: #10b981;"></i>
          <p><strong>Selected:</strong> ${fileName}</p>
          <p style="font-size: 0.75rem;">Size: ${fileSize} | Type: ${fileType}</p>
          <p style="font-size: 0.75rem; color: #10b981;">✓ Ready to upload</p>
        </div>
      `
      
      // Add visual feedback to container
      const container = this.element.querySelector('.file-input-container, .file-input-container-series')
      if (container) {
        console.log('Adding visual feedback to container')
        container.classList.add('file-selected')
        container.style.borderColor = '#10b981'
        container.style.backgroundColor = 'rgba(16, 185, 129, 0.1)'
      } else {
        console.log('Container not found for visual feedback')
      }
    } else {
      console.log('Text target not found')
    }

    // Show preview for images
    if (file.type.startsWith('image/') && this.hasPreviewTarget) {
      console.log('Showing image preview')
      const reader = new FileReader()
      reader.onload = (e) => {
        this.previewTarget.innerHTML = `
          <img src="${e.target.result}" alt="Preview" style="max-width: 200px; max-height: 200px; border-radius: 8px; margin-top: 1rem;">
        `
      }
      reader.readAsDataURL(file)
    }
  }

  formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes'
    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
  }

  // Reset file input
  reset() {
    if (this.hasInputTarget) {
      this.inputTarget.value = ''
    }
    if (this.hasTextTarget) {
      this.textTarget.innerHTML = `
        <i class="fas fa-cloud-upload-alt mb-2" style="font-size: 2rem; color: #64748b;"></i>
        <p>Click to upload or drag and drop</p>
        <p style="font-size: 0.75rem;">Supported formats vary by field</p>
      `
    }
    if (this.hasPreviewTarget) {
      this.previewTarget.innerHTML = ''
    }
    
    const container = this.element.querySelector('.file-input-container, .file-input-container-series')
    if (container) {
      container.classList.remove('file-selected')
      container.style.borderColor = ''
      container.style.backgroundColor = ''
    }
  }
}
