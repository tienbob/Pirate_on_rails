import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tagSelect", "selectedTags", "yearFrom", "yearTo"]

  connect() {
    console.log("MovieSearchFormController connected");
    // Tag selection logic
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

    // Year dropdown logic
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
