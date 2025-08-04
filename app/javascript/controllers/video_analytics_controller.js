import { Controller } from "@hotwired/stimulus"

// Video analytics and security tracking controller
export default class extends Controller {
  static targets = ["video"]
  static values = { 
    movieId: String,
    csrfToken: String
  }

  connect() {
    this.startTime = Date.now()
    this.watchDuration = 0
    this.heartbeatInterval = null
    this.hasStartedWatching = false
    this.suspiciousActivity = 0

    this.setupVideoSecurity()
    this.setupVideoEvents()
    this.setupKeyboardShortcuts()
    this.setupAntiPiracy()
  }

  disconnect() {
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval)
    }
    
    // Send final update when controller disconnects
    if (this.hasStartedWatching && this.hasVideoTarget) {
      this.watchDuration += (Date.now() - this.startTime) / 1000
      this.sendWatchUpdate(false, true)
    }
  }

  setupVideoSecurity() {
    if (!this.hasVideoTarget) return

    const video = this.videoTarget

    // Security: Disable right-click on video
    video.addEventListener('contextmenu', (e) => {
      e.preventDefault()
      return false
    })

    // Disable video download
    video.controlsList = 'nodownload'

    // Video quality adjustment for performance
    if (video.videoWidth > 1920 && window.innerWidth < 1200) {
      video.style.maxWidth = '100%'
      video.style.height = 'auto'
    }
  }

  setupVideoEvents() {
    if (!this.hasVideoTarget) return

    const video = this.videoTarget

    // Track when user starts watching
    video.addEventListener('play', () => {
      if (!this.hasStartedWatching) {
        this.hasStartedWatching = true
        this.startTime = Date.now()
        
        // Send periodic heartbeats to track watch time
        this.heartbeatInterval = setInterval(() => this.sendWatchUpdate(), 30000)
      } else {
        // Resume watching
        this.startTime = Date.now()
        this.heartbeatInterval = setInterval(() => this.sendWatchUpdate(), 30000)
      }
    })

    // Track when user pauses
    video.addEventListener('pause', () => {
      this.watchDuration += (Date.now() - this.startTime) / 1000
      if (this.heartbeatInterval) {
        clearInterval(this.heartbeatInterval)
      }
    })

    // Track completion
    video.addEventListener('ended', () => {
      this.watchDuration += (Date.now() - this.startTime) / 1000
      if (this.heartbeatInterval) {
        clearInterval(this.heartbeatInterval)
      }
      this.sendWatchUpdate(true) // Mark as completed
    })
  }

  setupKeyboardShortcuts() {
    // Keyboard shortcuts with security considerations
    document.addEventListener('keydown', (e) => {
      if (!this.hasVideoTarget) return
      
      const video = this.videoTarget
      if (!video.matches(':focus') && document.activeElement !== video) return
      
      switch(e.code) {
        case 'Space':
          e.preventDefault()
          video.paused ? video.play() : video.pause()
          break
        case 'ArrowLeft':
          e.preventDefault()
          video.currentTime = Math.max(0, video.currentTime - 10)
          break
        case 'ArrowRight':
          e.preventDefault()
          video.currentTime = Math.min(video.duration, video.currentTime + 10)
          break
        case 'KeyF':
          e.preventDefault()
          if (video.requestFullscreen) {
            video.requestFullscreen()
          }
          break
      }
    })
  }

  setupAntiPiracy() {
    // Prevent video manipulation via developer tools
    if (window.devtools && window.devtools.open) {
      if (this.hasVideoTarget) {
        this.videoTarget.style.display = 'none'
        document.body.innerHTML = '<h3>Content protection active</h3>'
      }
    }

    // Basic anti-piracy: blur video if suspicious activity detected
    document.addEventListener('keydown', (e) => {
      if (!this.hasVideoTarget) return
      
      // Detect potential screen recording shortcuts
      if ((e.ctrlKey || e.metaKey) && e.shiftKey && e.code === 'KeyR') {
        this.suspiciousActivity++
        if (this.suspiciousActivity > 2) {
          this.videoTarget.style.filter = 'blur(20px)'
          setTimeout(() => {
            if (this.hasVideoTarget) {
              this.videoTarget.style.filter = 'none'
            }
          }, 5000)
        }
      }
    })
  }

  sendWatchUpdate(completed = false, sync = false) {
    if (!this.movieIdValue || !this.csrfTokenValue || !this.hasVideoTarget) return

    const video = this.videoTarget
    const data = {
      movie_id: this.movieIdValue,
      watch_duration: Math.round(this.watchDuration),
      completed_viewing: completed,
      current_time: Math.round(video.currentTime || 0),
      total_duration: Math.round(video.duration || 0),
      timestamp: new Date().toISOString()
    }

    const requestOptions = {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.csrfTokenValue,
        'X-Requested-With': 'XMLHttpRequest'
      },
      body: JSON.stringify(data)
    }

    if (sync) {
      // Use sendBeacon for synchronous requests on page unload
      const formData = new FormData()
      formData.append('movie_id', this.movieIdValue)
      formData.append('watch_duration', Math.round(this.watchDuration))
      formData.append('completed_viewing', completed)
      formData.append('authenticity_token', this.csrfTokenValue)
      
      navigator.sendBeacon('/api/track_view', formData)
    } else {
      // Regular async request
      fetch('/api/track_view', requestOptions)
        .catch(error => console.error('Failed to track view:', error))
    }
  }

  // Action methods that can be called from the view
  playVideo() {
    if (this.hasVideoTarget && this.videoTarget.paused) {
      this.videoTarget.play()
    }
  }

  pauseVideo() {
    if (this.hasVideoTarget && !this.videoTarget.paused) {
      this.videoTarget.pause()
    }
  }

  toggleFullscreen() {
    if (this.hasVideoTarget && this.videoTarget.requestFullscreen) {
      this.videoTarget.requestFullscreen()
    }
  }
}
