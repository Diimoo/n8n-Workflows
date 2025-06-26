<template>
  <div id="app-container">
    <header>
      <h1>Aura - Meeting Protocol</h1>
    </header>
    <main>
      <AudioRecorder @recording-complete="handleRecording" :disabled="isLoading" />
      <div v-if="isLoading" class="loading-message">
        <p>Processing... Please wait.</p>
        <!-- You could add a spinner animation here -->
      </div>
      <div v-if="errorMessage" class="error-message">
        <p>Error: {{ errorMessage }}</p>
      </div>
      <TranscriptionDisplay :rawText="rawTranscription" :enhancedText="enhancedTranscription" />
      <PdfGenerator :textToConvert="enhancedTranscription" v-if="enhancedTranscription && !isLoading && !errorMessage" />
    </main>
    <footer>
      <p>Aura PWA - Offline Capable</p>
    </footer>
  </div>
</template>

<script setup>
import { ref } from 'vue';
import AudioRecorder from './components/AudioRecorder.vue';
import TranscriptionDisplay from './components/TranscriptionDisplay.vue';
import PdfGenerator from './components/PdfGenerator.vue';

const rawTranscription = ref('');
const enhancedTranscription = ref('');
const audioFile = ref(null); // Stores the File object from AudioRecorder
const isLoading = ref(false);
const errorMessage = ref('');

// Define backend URL. Adjust if your backend runs on a different port/host.
const BACKEND_URL = 'http://localhost:8000'; // Or use environment variable

const handleRecording = async (file) => {
  audioFile.value = file;
  rawTranscription.value = '';
  enhancedTranscription.value = '';
  errorMessage.value = '';
  isLoading.value = true;

  console.log('Audio file received, processing started:', file.name);

  const formData = new FormData();
  formData.append('file', file);

  try {
    // Step 1: Upload audio (optional, could be combined with transcribe)
    // For simplicity, let's assume transcription endpoint handles the file directly.
    // If you had a separate /upload-audio endpoint you wanted to call first:
    // const uploadResponse = await fetch(`${BACKEND_URL}/upload-audio/`, {
    //   method: 'POST',
    //   body: formData,
    // });
    // if (!uploadResponse.ok) {
    //   const errorData = await uploadResponse.json().catch(() => ({ detail: 'Failed to upload audio.' }));
    //   throw new Error(`Audio upload failed: ${uploadResponse.status} ${errorData.detail || uploadResponse.statusText}`);
    // }
    // const uploadResult = await uploadResponse.json();
    // console.log('Upload successful:', uploadResult);

    // Step 2: Transcribe audio
    console.log('Sending audio for transcription...');
    const transcribeResponse = await fetch(`${BACKEND_URL}/transcribe/`, {
      method: 'POST',
      body: formData, // Sending the same form data with the file
    });

    if (!transcribeResponse.ok) {
      const errorData = await transcribeResponse.json().catch(() => ({ detail: 'Failed to transcribe audio.' }));
      throw new Error(`Transcription failed: ${transcribeResponse.status} ${errorData.detail || transcribeResponse.statusText}`);
    }
    const transcriptionResult = await transcribeResponse.json();
    rawTranscription.value = transcriptionResult.transcription;
    console.log('Raw transcription received:', rawTranscription.value);

    // Step 3: Enhance text
    if (rawTranscription.value) {
      console.log('Sending raw transcription for enhancement...');
      const enhanceResponse = await fetch(`${BACKEND_URL}/enhance-text/`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ 
          text: rawTranscription.value,
          original_filename_stem: audioFile.value ? audioFile.value.name.substring(0, audioFile.value.name.lastIndexOf('.')) : 'unknown_audio'
        }),
      });

      if (!enhanceResponse.ok) {
        const errorData = await enhanceResponse.json().catch(() => ({ detail: 'Failed to enhance text.' }));
        throw new Error(`Text enhancement failed: ${enhanceResponse.status} ${errorData.detail || enhanceResponse.statusText}`);
      }
      const enhancementResult = await enhanceResponse.json();
      enhancedTranscription.value = enhancementResult.enhanced_text;
      console.log('Enhanced transcription received:', enhancedTranscription.value);
    } else {
      // If raw transcription is empty, just show that.
      enhancedTranscription.value = "(No raw transcription to enhance)";
    }

  } catch (error) {
    console.error('Error during processing:', error);
    errorMessage.value = error.message || 'An unexpected error occurred.';
    // Keep raw transcription if it was fetched before enhancement failed
    if (!rawTranscription.value) rawTranscription.value = "Error during processing.";
    if (!enhancedTranscription.value) enhancedTranscription.value = "Error during processing.";
  } finally {
    isLoading.value = false;
    console.log('Processing finished.');
  }
};

</script>

<style>
/* Basic styling for layout */
#app-container {
  font-family: Avenir, Helvetica, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-align: center;
  color: #2c3e50;
  margin: 0 auto;
  padding: 20px;
  max-width: 800px;
}

header {
  margin-bottom: 20px;
  border-bottom: 1px solid #eee;
  padding-bottom: 10px;
}

main > * {
  margin-bottom: 20px;
}

footer {
  margin-top: 30px;
  padding-top: 10px;
  border-top: 1px solid #eee;
  font-size: 0.8em;
  color: #666;
}

.loading-message {
  background-color: #e0e0e0;
  padding: 10px;
  border-radius: 5px;
  margin-bottom: 15px;
}

.error-message {
  background-color: #ffdddd;
  color: #d8000c;
  padding: 10px;
  border-radius: 5px;
  margin-bottom: 15px;
}
</style>
