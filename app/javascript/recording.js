'use strict';
const record = document.querySelector("#buttonRecord");
const stop = document.querySelector("#buttonStop");
const audio = document.querySelector("#player");

if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
  console.log("getUserMedia supported.");
  navigator.mediaDevices
    .getUserMedia(
      // 制約 - 音声のみがこのアプリでは必要
      {
        audio: true,
      },
    )

    // 成功コールバック
    .then((stream) => {
      console.log('getUserMediaはサポートされています')
      const mediaRecorder = new MediaRecorder(stream);
      record.onclick = () => {
        mediaRecorder.start();
        console.log(mediaRecorder.state);
        console.log("recorder started");
        record.setAttribute('disabled', '');
        stop.removeAttribute('disabled');        
      };

      let chunks = [];

      mediaRecorder.ondataavailable = (e) => {
        chunks.push(e.data);
      };

      stop.onclick = () => {
        mediaRecorder.stop();
        console.log(mediaRecorder.state);
        console.log("recorder stopped");
        record.removeAttribute('disabled');
        stop.setAttribute('disabled', '');
      };

      mediaRecorder.onstop = (e) => {
        const blob = new Blob(chunks, { type: "audio/webm; codecs=opus" });
        chunks = [];
        const audioURL = window.URL.createObjectURL(blob);
        audio.src = audioURL;
      };

    })

    // エラーコールバック
    .catch((err) => {
      console.error(`The following getUserMedia error occurred: ${err}`);
    });
} else {
  console.log("getUserMedia not supported on your browser!");
}
