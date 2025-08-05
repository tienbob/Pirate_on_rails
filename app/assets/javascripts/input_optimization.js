// Input Lag Optimization
(function() {
  'use strict';
  
  document.addEventListener('DOMContentLoaded', function() {
  // Optimize all input fields for better responsiveness
  function optimizeInputs() {
    const inputs = document.querySelectorAll('input, textarea, select');
    
    inputs.forEach(input => {
      // Remove heavy animations during typing
      input.addEventListener('focus', function() {
        this.style.willChange = 'contents';
        document.body.style.pointerEvents = 'auto'; // Ensure inputs are responsive
      });
      
      input.addEventListener('blur', function() {
        this.style.willChange = 'auto';
      });
      
      // Debounce input events to prevent excessive processing
      let inputTimeout;
      input.addEventListener('input', function(e) {
        clearTimeout(inputTimeout);
        inputTimeout = setTimeout(() => {
          // Process input change here if needed
          e.target.dispatchEvent(new CustomEvent('debouncedInput', { 
            detail: { value: e.target.value } 
          }));
        }, 150);
      });
    });
  }

  // Optimize form submissions
  function optimizeForms() {
    const forms = document.querySelectorAll('form');
    
    forms.forEach(form => {
      form.addEventListener('submit', function() {
        // Disable form temporarily to prevent double submissions
        const submitBtns = this.querySelectorAll('button[type="submit"], input[type="submit"]');
        submitBtns.forEach(btn => {
          btn.disabled = true;
          setTimeout(() => btn.disabled = false, 2000);
        });
      });
    });
  }

  // Optimize button clicks
  function optimizeButtons() {
    const buttons = document.querySelectorAll('button, .btn, [role="button"]');
    
    buttons.forEach(button => {
      button.addEventListener('mousedown', function() {
        this.style.transform = 'scale(0.98)';
      });
      
      button.addEventListener('mouseup', function() {
        this.style.transform = '';
      });
      
      button.addEventListener('mouseleave', function() {
        this.style.transform = '';
      });
    });
  }

  // Reduce DOM reflows during scrolling
  let scrollTimeout;
  let isScrolling = false;
  
  window.addEventListener('scroll', function() {
    if (!isScrolling) {
      document.body.classList.add('scrolling');
      isScrolling = true;
    }
    
    clearTimeout(scrollTimeout);
    scrollTimeout = setTimeout(() => {
      document.body.classList.remove('scrolling');
      isScrolling = false;
    }, 150);
  }, { passive: true });

  // Run optimizations
  optimizeInputs();
  optimizeForms();
  optimizeButtons();

  // Monitor performance
  const observer = new PerformanceObserver((list) => {
    const entries = list.getEntries();
    entries.forEach((entry) => {
      if (entry.entryType === 'measure' && entry.duration > 16) {
        console.warn(`Slow operation detected: ${entry.name} took ${entry.duration}ms`);
      }
    });
  });
  
  if (window.PerformanceObserver) {
    observer.observe({ entryTypes: ['measure', 'navigation'] });
  }
  
  // CSS for input optimization during scrolling
  const inputScrollCSS = `
    .scrolling * {
      pointer-events: none !important;
    }
    .scrolling input,
    .scrolling textarea,
    .scrolling button,
    .scrolling [role="button"] {
      pointer-events: auto !important;
    }
  `;

  const inputOptimizationStyle = document.createElement('style');
  inputOptimizationStyle.textContent = inputScrollCSS;
  document.head.appendChild(inputOptimizationStyle);
  
  console.log('Input optimization loaded');
});

})(); // End of IIFE
