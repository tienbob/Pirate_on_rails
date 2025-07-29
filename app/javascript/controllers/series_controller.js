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
    console.log("SeriesSearchFormController connected");

    // --- Tag selection logic ---
    // This logic lets users select/deselect tags for searching series.
    // The selected tags are stored in a hidden input for form submission.
    // When used with Turbo Frames, submitting the form will only update the results frame.
    let selected = [];
    if (this.hasTagSelectTarget && this.hasSelectedTagsTarget) {
      this.tagSelectTarget.querySelectorAll('.tag-option').forEach(tagEl => {
        tagEl.addEventListener('click', () => {
          const tag = tagEl.getAttribute('data-tag');
          if (selected.includes(tag)) {
            selected = selected.filter(t => t !== tag);
            tagEl.classList.remove('bg-primary');
            tagEl.classList.add('bg-secondary');
          } else {
            selected.push(tag);
            tagEl.classList.remove('bg-secondary');
            tagEl.classList.add('bg-primary');
          }
          this.selectedTagsTarget.value = selected.join(',');
        });
      });
      // On form submit, add hidden inputs for each selected tag.
      // Turbo will submit the form via AJAX and update the results frame.
      document.getElementById('series-search-form').addEventListener('submit', e => {
        document.querySelectorAll('input[name="tags[]"]').forEach(el => el.remove());
        selected.forEach(tag => {
          const input = document.createElement('input');
          input.type = 'hidden';
          input.name = 'tags[]';
          input.value = tag;
          e.target.appendChild(input);
        });
        // Ensure the selected search_type is submitted (handled by browser, but can be enforced here if needed)
        // No extra JS needed unless you want to dynamically change form behavior based on search_type
      });
    }
  }
}
