import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results"]
  static values = { url: String }

  connect() {
    this.timeout = null
    this.minLength = 3
    this.debounceDelay = 500
  }

  search() {
    clearTimeout(this.timeout)
    
    const query = this.inputTarget.value.trim()
    
    if (query.length < this.minLength) {
      this.hideResults()
      return
    }

    this.timeout = setTimeout(() => {
      this.fetchResults(query)
    }, this.debounceDelay)
  }

  async fetchResults(query) {
    try {
      const url = `${this.urlValue}?q=${encodeURIComponent(query)}`
      const response = await fetch(url)
      const data = await response.json()
      
      if (data.length > 0) {
        this.displayResults(data)
      } else {
        this.hideResults()
      }
    } catch (error) {
      console.error('検索エラー:', error)
      this.hideResults()
    }
  }

  displayResults(results) {
    this.resultsTarget.innerHTML = results.map(result => `
      <li data-action="click->youtube-autocomplete#select" 
          data-value="${this.escapeHtml(result.value)}">
        <div class="result-title">${this.escapeHtml(result.label)}</div>
        <div class="result-channel">${this.escapeHtml(result.channel)}</div>
      </li>
    `).join('')
    
    this.resultsTarget.classList.add('show')
  }

  hideResults() {
    this.resultsTarget.innerHTML = ''
    this.resultsTarget.classList.remove('show')
  }

  select(event) {
    const value = event.currentTarget.dataset.value
    this.inputTarget.value = event.currentTarget.querySelector('.result-title').textContent
    this.hideResults()
    this.element.querySelector('form').submit()
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}
