import { Controller } from "@hotwired/stimulus"

// connect() はこのdivがブラウザに追加された瞬間に自動で呼ばれる
export default class extends Controller {
  connect() {
    const recordingId = this.data.get("recording-id")
    console.log(`Recording ${recordingId} の生成完了！マイページに飛びます`)

    // マイページに自動で移動
    window.location.href = "/mypage"
  }
}
