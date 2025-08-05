// Scroll Performance Optimization
(function() {
    let scrollTimeout;
    let isScrolling = false;
    let raf;
    
    // List of heavy backdrop-filter elements to optimize
    const heavyBlurSelectors = [
        '.cinema-alert',
        '.cinema-chat-popup', 
        '.cinema-main-content',
        '.cinema-card',
        '.cinema-form-container',
        '.cinema-user-card',
        '.cinema-series-container',
        '.cinema-movie-container'
    ];
    
    // Throttled scroll handler for better performance
    function handleScroll() {
        if (!isScrolling) {
            // Add scrolling class to reduce expensive effects
            document.body.classList.add('scrolling');
            isScrolling = true;
            
            // Temporarily reduce backdrop-filter blur during scroll
            heavyBlurSelectors.forEach(selector => {
                const elements = document.querySelectorAll(selector);
                elements.forEach(el => {
                    if (el.style.backdropFilter || window.getComputedStyle(el).backdropFilter !== 'none') {
                        el.style.setProperty('backdrop-filter', 'blur(2px)', 'important');
                        el.style.setProperty('transform', 'translateZ(0)', 'important');
                    }
                });
            });
        }
        
        // Clear existing timeout
        clearTimeout(scrollTimeout);
        
        // Set timeout to restore effects when scroll ends
        scrollTimeout = setTimeout(() => {
            document.body.classList.remove('scrolling');
            isScrolling = false;
            
            // Restore original backdrop-filter effects
            heavyBlurSelectors.forEach(selector => {
                const elements = document.querySelectorAll(selector);
                elements.forEach(el => {
                    el.style.removeProperty('backdrop-filter');
                });
            });
        }, 150);
    }
    
    // Use passive listener for better scroll performance
    window.addEventListener('scroll', handleScroll, { passive: true });
    
    // Optimize touch scrolling on mobile
    if ('ontouchstart' in window) {
        document.addEventListener('touchstart', function() {
            handleScroll();
        }, { passive: true });
        
        document.addEventListener('touchend', function() {
            setTimeout(() => {
                if (scrollTimeout) {
                    clearTimeout(scrollTimeout);
                    scrollTimeout = setTimeout(() => {
                        document.body.classList.remove('scrolling');
                        isScrolling = false;
                        
                        // Restore effects
                        heavyBlurSelectors.forEach(selector => {
                            const elements = document.querySelectorAll(selector);
                            elements.forEach(el => {
                                el.style.removeProperty('backdrop-filter');
                            });
                        });
                    }, 200);
                }
            }, 50);
        }, { passive: true });
    }
    
    // Optimize mouse wheel scrolling
    window.addEventListener('wheel', handleScroll, { passive: true });
    
    // Performance monitoring
    let lastScrollTime = performance.now();
    let scrollFrames = 0;
    
    function monitorScrollPerformance() {
        scrollFrames++;
        const now = performance.now();
        
        if (now - lastScrollTime > 1000) {
            const fps = Math.round((scrollFrames * 1000) / (now - lastScrollTime));
            
            // Log performance if below 30fps
            if (fps < 30) {
                console.log(`Scroll performance: ${fps}fps - Backdrop filters reduced during scroll`);
            }
            
            scrollFrames = 0;
            lastScrollTime = now;
        }
        
        if (isScrolling) {
            raf = requestAnimationFrame(monitorScrollPerformance);
        }
    }
    
    // Start monitoring during scroll
    window.addEventListener('scroll', () => {
        if (isScrolling && scrollFrames === 0) {
            raf = requestAnimationFrame(monitorScrollPerformance);
        }
    }, { passive: true });
    
    // Preload performance optimizations
    document.addEventListener('DOMContentLoaded', function() {
        // Force GPU layer creation for main elements
        const mainContent = document.querySelector('.cinema-main-content');
        if (mainContent) {
            mainContent.style.transform = 'translateZ(0)';
            mainContent.style.willChange = 'scroll-position';
        }
        
        // Optimize all heavy backdrop-filter elements
        heavyBlurSelectors.forEach(selector => {
            const elements = document.querySelectorAll(selector);
            elements.forEach(el => {
                el.style.transform = 'translateZ(0)';
                el.style.willChange = 'backdrop-filter, transform';
            });
        });
        
        // Add CSS for reduced motion preference
        if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
            const style = document.createElement('style');
            style.textContent = `
                * {
                    backdrop-filter: none !important;
                    transition: none !important;
                    animation: none !important;
                }
            `;
            document.head.appendChild(style);
        }
        
        console.log('Advanced scroll optimizations loaded - backdrop-filter management active');
    });
})();
