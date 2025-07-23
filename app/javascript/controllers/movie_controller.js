
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
    console.log("MovieSearchFormController connected");

    // --- Tag selection logic ---
    // This logic lets users select/deselect tags for searching movies.
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
      document.getElementById('movie-search-form').addEventListener('submit', e => {
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
