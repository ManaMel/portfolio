document.addEventListener('turbo:load', () => {
  const record = document.querySelector("#buttonRecord");
  const stop = document.querySelector("#buttonStop");
  const audio = document.querySelector("#player");

  if (!record || !stop || !audio) {
    console.log("録音用要素が存在しないため、スクリプトをスキップします。");
    return;
  }

  let mediaRecorder;
  let chunks = [];

  record.onclick = () => {
    navigator.mediaDevices.getUserMedia({ audio: true })
      .then((stream) => {
        mediaRecorder = new MediaRecorder(stream);
        chunks = [];

        mediaRecorder.ondataavailable = (e) => {
          chunks.push(e.data);
        };

        mediaRecorder.onstop = () => {
          const blob = new Blob(chunks, { type: "audio/webm; codecs=opus" });
          const audioURL = URL.createObjectURL(blob);
          audio.src = audioURL;
        };

        mediaRecorder.start();
        console.log("録音開始");

        record.disabled = true;
        stop.disabled = false;

        stop.onclick = () => {
          mediaRecorder.stop();
          console.log("録音停止");
          record.disabled = false;
          stop.disabled = true;
        };
      })
      .catch((err) => {
        console.error("マイク取得エラー:", err);
      });
  };
});
