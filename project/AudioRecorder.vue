<template>
  <div class="audio-recorder">
    <h2>1. Record Audio</h2>
    <button @click="startRecording" :disabled="isRecording || disabled">Start Recording</button>
    <button @click="stopRecording" :disabled="!isRecording || disabled">Stop Recording</button>
    <div v-if="audioURL">
      <audio :src="audioURL" controls></audio>
      <button @click="submitRecording" :disabled="disabled">Use this Recording</button>
    </div>
    <p v-if="isRecording">Recording in progress...</p>
    <p v-if="statusMessage">{{ statusMessage }}</p>
  </div>
</template>

<script setup>
import { ref, defineEmits, defineProps } from 'vue';

const props = defineProps({
  disabled: Boolean
});

const isRecording = ref(false);
const audioURL = ref(null);
const audioBlob = ref(null);
const mediaRecorder = ref(null);
const audioChunks = ref([]);
const statusMessage = ref('');

const emit = defineEmits(['recording-complete']);

const startRecording = async () => {
  statusMessage.value = '';
  audioURL.value = null;
  audioBlob.value = null;
  audioChunks.value = [];

  if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
    statusMessage.value = 'getUserMedia not supported on your browser!';
    return;
  }

  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    mediaRecorder.value = new MediaRecorder(stream);
    mediaRecorder.value.ondataavailable = event => {
      audioChunks.value.push(event.data);
    };
    mediaRecorder.value.onstop = () => {
      const blob = new Blob(audioChunks.value, { type: 'audio/wav' }); // Or 'audio/webm' etc.
      audioBlob.value = blob;
      audioURL.value = URL.createObjectURL(blob);
      isRecording.value = false;
    };
    mediaRecorder.value.start();
    isRecording.value = true;
    statusMessage.value = 'Recording started...';
  } catch (err) {
    console.error('Error accessing microphone:', err);
    statusMessage.value = `Error accessing microphone: ${err.message}. Please ensure permission is granted.`;
    isRecording.value = false;
  }
};

const stopRecording = () => {
  if (mediaRecorder.value && isRecording.value) {
    mediaRecorder.value.stop();
    // Get the tracks and stop them to turn off the microphone light/indicator
    mediaRecorder.value.stream.getTracks().forEach(track => track.stop());
    statusMessage.value = 'Recording stopped. Preview available.';
  }
};

const submitRecording = () => {
  if (audioBlob.value) {
    const fileName = `recording-${new Date().toISOString()}.wav`;
    const audioFile = new File([audioBlob.value], fileName, { type: audioBlob.value.type });
    emit('recording-complete', audioFile);
    statusMessage.value = 'Recording submitted!';
  } else {
    statusMessage.value = 'No recording available to submit.';
  }
};

</script>

<style scoped>
.audio-recorder {
  border: 1px solid #ccc;
  padding: 15px;
  border-radius: 8px;
  background-color: #f9f9f9;
}
.audio-recorder button {
  margin: 5px;
  padding: 8px 12px;
  cursor: pointer;
}
.audio-recorder audio {
  margin-top: 10px;
  width: 100%;
}
</style>
