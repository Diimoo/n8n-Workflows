<template>
  <div class="transcription-display">
    <h2>2. Transcription</h2>
    <div v-if="rawText || enhancedText">
      <div v-if="rawText">
        <h3>Raw Transcription:</h3>
        <textarea v-model="editableRawText" rows="5" placeholder="Raw transcription will appear here..."></textarea>
      </div>
      <div v-if="enhancedText">
        <h3>Enhanced Transcription:</h3>
        <textarea v-model="editableEnhancedText" rows="10" placeholder="Enhanced transcription will appear here..."></textarea>
        <button @click="copyEnhancedText">Copy Enhanced Text</button>
      </div>
    </div>
    <p v-else>Waiting for audio to be processed...</p>
    <p v-if="copyStatus">{{ copyStatus }}</p>
  </div>
</template>

<script setup>
import { ref, watch, defineProps, toRefs } from 'vue';

const props = defineProps({
  rawText: String,
  enhancedText: String
});

const { rawText, enhancedText } = toRefs(props);

const editableRawText = ref('');
const editableEnhancedText = ref('');
const copyStatus = ref('');

watch(rawText, (newVal) => {
  editableRawText.value = newVal;
});

watch(enhancedText, (newVal) => {
  editableEnhancedText.value = newVal;
});

const copyEnhancedText = async () => {
  if (!editableEnhancedText.value) {
    copyStatus.value = 'Nothing to copy.';
    return;
  }
  try {
    await navigator.clipboard.writeText(editableEnhancedText.value);
    copyStatus.value = 'Enhanced text copied to clipboard!';
  } catch (err) {
    copyStatus.value = 'Failed to copy text.';
    console.error('Failed to copy: ', err);
  }
  setTimeout(() => copyStatus.value = '', 3000);
};

</script>

<style scoped>
.transcription-display {
  border: 1px solid #ccc;
  padding: 15px;
  border-radius: 8px;
  background-color: #f9f9f9;
}
.transcription-display textarea {
  width: 95%;
  margin-top: 5px;
  margin-bottom: 10px;
  padding: 8px;
  border: 1px solid #ddd;
  border-radius: 4px;
}
.transcription-display button {
  margin-top: 5px;
  padding: 8px 12px;
  cursor: pointer;
}
</style>
