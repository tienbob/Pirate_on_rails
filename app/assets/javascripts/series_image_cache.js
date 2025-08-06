// Image caching for series to prevent hover requests
class SeriesImageCache {
  constructor() {
    this.cache = new Map();
    this.preloadImages();
  }

  // Preload all visible series images to prevent hover requests
  preloadImages() {
    const seriesImages = document.querySelectorAll('.series-card img, .series-poster');
    seriesImages.forEach(img => {
      if (img.src) {
        this.preloadImage(img.src);
      }
    });
  }

  preloadImage(src) {
    if (this.cache.has(src)) return;
    
    const img = new Image();
    img.onload = () => {
      this.cache.set(src, true);
    };
    img.src = src;
  }

  // Force browser to cache image by creating invisible img element
  static forceCache(imageSrc) {
    const img = new Image();
    img.style.display = 'none';
    img.src = imageSrc;
    document.body.appendChild(img);
    
    // Remove after cache
    setTimeout(() => {
      if (img.parentNode) {
        img.parentNode.removeChild(img);
      }
    }, 1000);
  }
}

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', function() {
  new SeriesImageCache();
  
  // Also force cache all series images immediately
  const seriesImages = document.querySelectorAll('.series-card img, .series-poster');
  seriesImages.forEach(img => {
    if (img.src) {
      SeriesImageCache.forceCache(img.src);
    }
  });
});
