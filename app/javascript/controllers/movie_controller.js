
// This Stimulus controller handles client-side interactivity for the movie search form.
// It works together with Turbo Frames (for partial page updates) and Turbo Streams (for real-time updates)
// to provide a modern Hotwire experience.
import { Controller } from "@hotwired/stimulus"


// Stimulus controller for the movie search form.
// Handles tag selection and year dropdown logic.
// The form and results should be wrapped in Turbo Frames in the view for best UX.
export default class extends Controller {
  static targets = ["tagSelect", "selectedTags", "yearFrom", "yearTo"]

  connect() {
    console.log("Movie controller connected");

    // --- Tag selection logic ---
    // This logic lets users select/deselect tags for searching movies.
    // The selected tags are stored in a hidden input for form submission.
    // When used with Turbo Frames, submitting the form will only update the results frame.
    let selected = [];
    if (this.hasTagSelectTarget && this.hasSelectedTagsTarget) {
      this.tagSelectTarget.querySelectorAll('.tag-option').forEach(tagEl => {
        const checkbox = tagEl.querySelector('input[type="checkbox"]');
        if (checkbox) {
          // Set initial highlight based on checked state
          if (checkbox.checked) {
            tagEl.classList.add('tag-selected');
            if (!selected.includes(checkbox.value)) selected.push(checkbox.value);
          }
          checkbox.addEventListener('change', () => {
            const tag = checkbox.value;
            if (checkbox.checked) {
              tagEl.classList.add('tag-selected');
              if (!selected.includes(tag)) selected.push(tag);
              console.log(`[Tag] Selected tag: ${tag}`);
            } else {
              tagEl.classList.remove('tag-selected');
              selected = selected.filter(t => t !== tag);
              console.log(`[Tag] Deselected tag: ${tag}`);
            }
            this.selectedTagsTarget.value = selected.join(',');
            console.log('[Tag] Tags ready to send:', selected);
          });
        }
      });
      // On form submit, add hidden inputs for each selected tag.
      // Turbo will submit the form via AJAX and update the results frame.
      const form = document.getElementById('movie-search-form');
      if (form) {
        form.addEventListener('submit', e => {
          document.querySelectorAll('input[name="tags[]"]').forEach(el => el.remove());
          selected.forEach(tag => {
            const input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'tags[]';
            input.value = tag;
            e.target.appendChild(input);
          });
        });
      }
    }

    // --- Year dropdown logic ---
    // Dynamically updates the 'year to' dropdown based on the 'year from' selection.
    // This is pure client-side logic, handled by Stimulus.
    if (this.hasYearFromTarget && this.hasYearToTarget) {
      const updateYearToOptions = () => {
        const fromYear = parseInt(this.yearFromTarget.value);
        const minYear = 2000;
        const maxYear = new Date().getFullYear();
        const currentTo = this.yearToTarget.value;
        while (this.yearToTarget.options.length > 1) this.yearToTarget.remove(1);
        let start = isNaN(fromYear) ? minYear : fromYear;
        for (let y = start; y <= maxYear; y++) {
          let opt = document.createElement('option');
          opt.value = y;
          opt.text = y;
          this.yearToTarget.appendChild(opt);
        }
        if (currentTo && parseInt(currentTo) >= start) this.yearToTarget.value = currentTo;
        else this.yearToTarget.value = '';
      };
      this.yearFromTarget.addEventListener('change', updateYearToOptions);
      updateYearToOptions();
    }
  }
}
