// Stimulus controller for the series new/edit form tag selection
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tagSelect", "selectedTags"];

  connect() {
    console.log('[series-form] Controller connected');
    let selected = [];
    if (this.hasTagSelectTarget && this.hasSelectedTagsTarget) {
      console.log('[series-form] tagSelect and selectedTags targets found');
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
              console.log(`[series-form] Selected tag: ${tag}`);
            } else {
              tagEl.classList.remove('tag-selected');
              selected = selected.filter(t => t !== tag);
              console.log(`[series-form] Deselected tag: ${tag}`);
            }
            this.selectedTagsTarget.value = selected.join(',');
            console.log('[series-form] Tags ready to send:', selected);
          });
        }
      });
      // On form submit, add hidden inputs for each selected tag.
      const form = this.element.closest('form');
      if (form) {
        form.addEventListener('submit', e => {
          console.log('[series-form] Form submit, selected:', selected);
          form.querySelectorAll('input[name="tags[]"]').forEach(el => el.remove());
          selected.forEach(tag => {
            const input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'tags[]';
            input.value = tag;
            form.appendChild(input);
          });
        });
      } else {
        console.warn('[series-form] No form found for tag selection!');
      }
    } else {
      console.warn('[series-form] tagSelect or selectedTags target missing!');
    }
  }
}
