'use strict';
 const record = document.querySelector("#buttonRecord");
 const stop = document.querySelector("#buttonStop");
 const audio = document.querySelector("#player");

 if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
   console.log("getUserMedia supported.");
   navigator.mediaDevices
     .getUserMedia(
       {
         audio: true,
       }
     )
     .then((stream) => {
       console.log('getUserMediaはサポートされています');
       const mediaRecorder = new MediaRecorder(stream);
       let chunks = [];

       record.onclick = () => {
         mediaRecorder.start();
         console.log(mediaRecorder.state);
         console.log("recorder started");
         record.setAttribute('disabled', '');
         stop.removeAttribute('disabled');
       };

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
         const blob = new Blob(chunks, { type: "audio/mp4; codecs=opus" });
         chunks = [];
         const audioURL = window.URL.createObjectURL(blob);
         audio.src = audioURL;
       };
    })
     .catch((err) => {
       console.error(`The following getUserMedia error occurred: ${err}`);
     });
 } else {
   console.log("getUserMedia not supported on your browser!");
 }
