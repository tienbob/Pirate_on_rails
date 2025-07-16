// Handles tag selection and year dropdown logic for the movie search form

document.addEventListener('turbo:load', function() {
  // Tag selection logic
  const tagSelect = document.getElementById('tag-select');
  const selectedTagsInput = document.getElementById('selected-tags');
  let selected = [];
  if (tagSelect && selectedTagsInput) {
    tagSelect.querySelectorAll('.tag-option').forEach(function(tagEl) {
      tagEl.addEventListener('click', function() {
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
        selectedTagsInput.value = selected.join(',');
      });
    });
    // On submit, convert comma string to multiple hidden inputs
    document.getElementById('movie-search-form').addEventListener('submit', function(e) {
      document.querySelectorAll('input[name="tags[]"]').forEach(el => el.remove());
      selected.forEach(function(tag) {
        const input = document.createElement('input');
        input.type = 'hidden';
        input.name = 'tags[]';
        input.value = tag;
        e.target.appendChild(input);
      });
    });
  }

  // Year dropdown logic
  const yearFrom = document.getElementById('year-from');
  const yearTo = document.getElementById('year-to');
  if (yearFrom && yearTo) {
    function updateYearToOptions() {
      const fromVal = parseInt(yearFrom.value);
      const minYear = 2000;
      const maxYear = new Date().getFullYear();
      const currentTo = yearTo.value;
      while (yearTo.options.length > 1) yearTo.remove(1);
      let start = isNaN(fromVal) ? minYear : fromVal;
      for (let y = start; y <= maxYear; y++) {
        let opt = document.createElement('option');
        opt.value = y;
        opt.text = y;
        yearTo.appendChild(opt);
      }
      if (currentTo && currentTo >= start) yearTo.value = currentTo;
      else yearTo.value = '';
    }
    yearFrom.addEventListener('change', updateYearToOptions);
    updateYearToOptions();
  }
});
