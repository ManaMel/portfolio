/** @type {import('tailwindcss').Config} */
module.exports = {
  // Tailwindが適用されるファイルを指定
  content: [
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/views/**/*.{erb,haml,html,slim}'
  ],
  theme: {
    extend: {},
  },
  // 💡 daisyUIプラグインの登録（これが最重要）
  plugins: [
    require('daisyui'),
  ],
  // daisyUIのカスタム設定（オプション）
  daisyui: {
    styled: true,
    themes: ["light", "dark", "cupcake"],
    base: true,
    utils: true,
    logs: false,
    prefix: "",
    darkTheme: "dark",
  },
}
