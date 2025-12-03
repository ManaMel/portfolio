/** @type {import('tailwindcss').Config} */
module.exports = {
  // Rails 7 のデフォルトかつ DaisyUI を含めるための最小構成
  content: [
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/views/**/*.{erb,haml,html,slim}',
  ],
  theme: {
    extend: {},
  },
  plugins: [
    require('daisyui'),
  ],
  // DaisyUI の設定は必須ではありませんが、残しておきます
  daisyui: {
    themes: ["light", "dark", "cupcake"],
  },
}
