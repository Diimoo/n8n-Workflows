<template>
  <div class="pdf-generator">
    <h2>3. Generate PDF Protocol</h2>
    <button @click="generatePdf" :disabled="!textToConvert">Download PDF</button>
    <p v-if="statusMessage">{{ statusMessage }}</p>
  </div>
</template>

<script setup>
import { ref, defineProps, toRefs } from 'vue';
import { jsPDF } from 'jspdf'; // Using jsPDF for client-side generation

const props = defineProps({
  textToConvert: String
});

const { textToConvert } = toRefs(props);
const statusMessage = ref('');

const generatePdf = () => {
  if (!textToConvert.value) {
    statusMessage.value = 'No text available to generate PDF.';
    return;
  }
  statusMessage.value = 'Generating PDF...';
  try {
    const doc = new jsPDF();
    
    // Basic PDF structure
    doc.setFontSize(18);
    doc.text("Meeting Protocol", 20, 20);
    
    doc.setFontSize(12);
    // Add meeting metadata (placeholders for now)
    doc.text(`Date: ${new Date().toLocaleDateString()}`, 20, 30);
    doc.text("Attendees: Placeholder", 20, 35); // This could be an input field later
    doc.text("Topic: Meeting Recording", 20, 40);

    doc.setFontSize(12);
    // Add the enhanced transcript. jsPDF's text method can handle line breaks.
    // For long text, it might need splitting or more advanced layout.
    const splitText = doc.splitTextToSize(textToConvert.value, 170); // 170mm width
    doc.text(splitText, 20, 50);
    
    doc.save("Aura-Meeting-Protocol.pdf");
    statusMessage.value = 'PDF downloaded successfully!';
  } catch (error) {
    console.error("Error generating PDF:", error);
    statusMessage.value = `Error generating PDF: ${error.message}`;
  }
  setTimeout(() => statusMessage.value = '', 3000);
};

</script>

<style scoped>
.pdf-generator {
  border: 1px solid #ccc;
  padding: 15px;
  border-radius: 8px;
  background-color: #f9f9f9;
}
.pdf-generator button {
  padding: 8px 12px;
  cursor: pointer;
}
</style>
