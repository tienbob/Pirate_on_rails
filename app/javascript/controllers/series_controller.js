// This Stimulus controller handles client-side interactivity for the series search form.
// It works together with Turbo Frames (for partial page updates) and Turbo Streams (for real-time updates)
// to provide a modern Hotwire experience.
import { Controller } from "@hotwired/stimulus"

// Stimulus controller for the series search form.
// Handles tag selection logic and loading animation.
// The form and results should be wrapped in Turbo Frames in the view for best UX.
export default class extends Controller {
  static targets = ["tagSelect", "selectedTags"]

  connect() {
    console.log("Series controller connected");

    // --- Tag selection logic for elastic search ---
    // This logic lets users select/deselect tags for searching series.
    // The selected tags are stored in a hidden input for form submission.
    // When used with Turbo Frames, submitting the form will only update the results frame.
    let selected = [];
    if (this.hasTagSelectTarget && this.hasSelectedTagsTarget) {
      // Initialize selected from hidden input value
      const initial = this.selectedTagsTarget.value;
      if (initial) {
        selected = initial.split(',').map(t => t.trim()).filter(t => t.length > 0);
      }
      this.tagSelectTarget.querySelectorAll('.tag-option-series').forEach(tagEl => {
        const tag = tagEl.getAttribute('data-tag');
        // Set initial highlight
        if (selected.includes(tag)) {
          tagEl.classList.add('selected');
        } else {
          tagEl.classList.remove('selected');
        }
        tagEl.addEventListener('click', () => {
          if (selected.includes(tag)) {
            selected = selected.filter(t => t !== tag);
            tagEl.classList.remove('selected');
          } else {
            selected.push(tag);
            tagEl.classList.add('selected');
          }
          this.selectedTagsTarget.value = selected.join(',');
        });
      });
    }

    // Set up loading animation with better event handling
    this.setupLoadingAnimation();
  }

  setupLoadingAnimation() {
    // Listen for Turbo Frame events on the document
    document.addEventListener('turbo:frame-load', (event) => {
      console.log('Turbo frame loaded:', event.target.id);
      if (event.target.id === 'series') {
        this.hideLoading();
      }
    });

    document.addEventListener('turbo:frame-missing', (event) => {
      console.log('Turbo frame missing:', event.target.id);
      if (event.target.id === 'series') {
        this.hideLoading();
      }
    });

    // Also hide loading after a timeout as fallback
    document.addEventListener('turbo:submit-start', (event) => {
      if (event.target.id === 'series-search-form') {
        console.log('Search form submitted, showing loading');
        this.showLoading();
        // Fallback: hide loading after 10 seconds
        setTimeout(() => {
          this.hideLoading();
        }, 10000);
      }
    });
  }

  showLoading() {
    console.log('Showing loading animation');
    const loadingEl = document.getElementById('search-loading');
    const resultsEl = document.getElementById('search-results');
    
    if (loadingEl) {
      loadingEl.style.display = 'block';
      console.log('Loading element shown');
    } else {
      console.warn('Loading element not found');
    }
    
    if (resultsEl) {
      resultsEl.style.display = 'none';
      console.log('Results element hidden');
    } else {
      console.warn('Results element not found');
    }
  }

  hideLoading() {
    console.log('Hiding loading animation');
    const loadingEl = document.getElementById('search-loading');
    const resultsEl = document.getElementById('search-results');
    
    if (loadingEl) {
      loadingEl.style.display = 'none';
      console.log('Loading element hidden');
    }
    
    if (resultsEl) {
      resultsEl.style.display = 'block';
      console.log('Results element shown');
    }
  }
}
