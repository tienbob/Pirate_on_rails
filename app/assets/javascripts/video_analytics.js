// Video analytics and security tracking
document.addEventListener('DOMContentLoaded', function() {
  const video = document.querySelector('.movie-video');
  if (!video) return;

  const movieId = video.dataset.movieId;
  const csrfToken = video.dataset.csrfToken;
  
  if (!movieId || !csrfToken) return;

  let startTime = Date.now();
  let watchDuration = 0;
  let heartbeatInterval;
  let hasStartedWatching = false;

  // Security: Disable right-click on video
  video.addEventListener('contextmenu', function(e) {
    e.preventDefault();
    return false;
  });

  // Disable video download
  video.controlsList = 'nodownload';

  // Track when user starts watching
  video.addEventListener('play', function() {
    if (!hasStartedWatching) {
      hasStartedWatching = true;
      startTime = Date.now();
      
      // Send periodic heartbeats to track watch time
      heartbeatInterval = setInterval(sendWatchUpdate, 30000); // Every 30 seconds
    }
  });

  // Track when user pauses
  video.addEventListener('pause', function() {
    watchDuration += (Date.now() - startTime) / 1000;
    clearInterval(heartbeatInterval);
  });

  // Track when user resumes
  video.addEventListener('play', function() {
    startTime = Date.now();
    heartbeatInterval = setInterval(sendWatchUpdate, 30000);
  });

  // Track completion
  video.addEventListener('ended', function() {
    watchDuration += (Date.now() - startTime) / 1000;
    clearInterval(heartbeatInterval);
    
    sendWatchUpdate(true); // Mark as completed
  });

  // Send final update when user leaves
  window.addEventListener('beforeunload', function() {
    if (hasStartedWatching) {
      watchDuration += (Date.now() - startTime) / 1000;
      sendWatchUpdate(false, true); // Sync request
    }
  });

  function sendWatchUpdate(completed = false, sync = false) {
    const data = {
      movie_id: movieId,
      watch_duration: Math.round(watchDuration),
      completed_viewing: completed,
      current_time: Math.round(video.currentTime),
      total_duration: Math.round(video.duration),
      timestamp: new Date().toISOString()
    };

    const requestOptions = {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken,
        'X-Requested-With': 'XMLHttpRequest'
      },
      body: JSON.stringify(data)
    };

    if (sync) {
      // Use sendBeacon for synchronous requests on page unload
      const formData = new FormData();
      formData.append('movie_id', movieId);
      formData.append('watch_duration', Math.round(watchDuration));
      formData.append('completed_viewing', completed);
      formData.append('authenticity_token', csrfToken);
      
      navigator.sendBeacon('/api/track_view', formData);
    } else {
      // Regular async request
      fetch('/api/track_view', requestOptions)
        .catch(error => console.error('Failed to track view:', error));
    }
  }

  // Video quality adjustment for performance
  if (video.videoWidth > 1920 && window.innerWidth < 1200) {
    // Suggest lower quality for smaller screens
    video.style.maxWidth = '100%';
    video.style.height = 'auto';
  }

  // Keyboard shortcuts with security considerations
  document.addEventListener('keydown', function(e) {
    if (!video.matches(':focus') && document.activeElement !== video) return;
    
    switch(e.code) {
      case 'Space':
        e.preventDefault();
        video.paused ? video.play() : video.pause();
        break;
      case 'ArrowLeft':
        e.preventDefault();
        video.currentTime = Math.max(0, video.currentTime - 10);
        break;
      case 'ArrowRight':
        e.preventDefault();
        video.currentTime = Math.min(video.duration, video.currentTime + 10);
        break;
      case 'KeyF':
        e.preventDefault();
        if (video.requestFullscreen) {
          video.requestFullscreen();
        }
        break;
    }
  });

  // Prevent video manipulation via developer tools
  if (window.devtools && window.devtools.open) {
    video.style.display = 'none';
    document.body.innerHTML = '<h3>Content protection active</h3>';
  }

  // Basic anti-piracy: blur video if suspicious activity detected
  let suspiciousActivity = 0;
  
  document.addEventListener('keydown', function(e) {
    // Detect potential screen recording shortcuts
    if ((e.ctrlKey || e.metaKey) && e.shiftKey && e.code === 'KeyR') {
      suspiciousActivity++;
      if (suspiciousActivity > 2) {
        video.style.filter = 'blur(20px)';
        setTimeout(() => video.style.filter = 'none', 5000);
      }
    }
  });
});
