// Frontend Performance Optimizations for Series Index
document.addEventListener('DOMContentLoaded', function() {
  // Optimize image loading with Intersection Observer
  if ('IntersectionObserver' in window) {
    const imageObserver = new IntersectionObserver((entries, observer) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          const img = entry.target;
          if (img.dataset.src) {
            img.src = img.dataset.src;
            img.classList.remove('lazy');
            imageObserver.unobserve(img);
          }
        }
      });
    }, {
      rootMargin: '50px 0px',
      threshold: 0.01
    });

    // Observe all lazy images
    document.querySelectorAll('img[data-src]').forEach(img => {
      imageObserver.observe(img);
    });
  }

  // Optimize animations with requestAnimationFrame
  let ticking = false;
  
  function optimizeHoverEffects() {
    if (!ticking) {
      requestAnimationFrame(function() {
        // Batch DOM operations here if needed
        ticking = false;
      });
      ticking = true;
    }
  }

  // Debounce scroll events for better performance
  let scrollTimeout;
  window.addEventListener('scroll', function() {
    if (scrollTimeout) {
      cancelAnimationFrame(scrollTimeout);
    }
    scrollTimeout = requestAnimationFrame(optimizeHoverEffects);
  });

  // Preload critical CSS if not already loaded
  const criticalCSS = [
    'cinema_series_search',
    'cinema_series_results'
  ];

  criticalCSS.forEach(cssFile => {
    const link = document.createElement('link');
    link.rel = 'preload';
    link.as = 'style';
    link.href = `/assets/${cssFile}.css`;
    link.onload = function() {
      this.rel = 'stylesheet';
    };
    document.head.appendChild(link);
  });

  // Optimize tag rendering with virtual scrolling for large lists
  function optimizeTagDisplay() {
    const tagContainers = document.querySelectorAll('.series-card-tags');
    tagContainers.forEach(container => {
      // Limit visible tags and add "show more" if needed
      const tags = container.querySelectorAll('.series-card-tag');
      if (tags.length > 3) {
        for (let i = 3; i < tags.length; i++) {
          tags[i].style.display = 'none';
        }
        
        const showMore = document.createElement('span');
        showMore.className = 'series-card-tag show-more';
        showMore.textContent = `+${tags.length - 3} more`;
        showMore.style.cursor = 'pointer';
        showMore.addEventListener('click', function() {
          for (let i = 3; i < tags.length; i++) {
            tags[i].style.display = 'inline-block';
          }
          this.style.display = 'none';
        });
        container.appendChild(showMore);
      }
    });
  }

  // Run optimization after DOM is ready
  optimizeTagDisplay();
});

// Performance monitoring
if (window.performance) {
  window.addEventListener('load', function() {
    const loadTime = window.performance.timing.loadEventEnd - window.performance.timing.navigationStart;
    if (loadTime > 3000) { // Log slow loads
      console.warn(`Page load took ${loadTime}ms - consider optimization`);
    }
  });
}
