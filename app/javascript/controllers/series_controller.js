// This Stimulus controller handles client-side interactivity for the series search form.
// It works together with Turbo Frames (for partial page updates) and Turbo Streams (for real-time updates)
// to provide a modern Hotwire experience.
import { Controller } from "@hotwired/stimulus"

// Stimulus controller for the series search form.
// Handles tag selection logic.
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
      // On form submit, update hidden input value
      const form = document.getElementById('series-search-form');
      if (form) {
        form.addEventListener('submit', e => {
          this.selectedTagsTarget.value = selected.join(',');
        });
      } else {
        console.warn('[series-controller] series-search-form not found!');
      }
    }
  }
}
