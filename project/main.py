from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import os
import shutil
from pathlib import Path

# Define base directory for data storage
DATA_DIR = Path("../data") # Relative to the app directory
AUDIO_FILES_DIR = DATA_DIR / "audio_files"
TRANSCRIPTS_DIR = DATA_DIR / "transcripts"
PDF_DIR = DATA_DIR / "pdfs" # Though PDF is client-side, create dir if future use.
TEMP_AUDIO_DIR = DATA_DIR / "temp_audio" # For temporary processing if needed

# Create directories if they don't exist
os.makedirs(AUDIO_FILES_DIR, exist_ok=True)
os.makedirs(TRANSCRIPTS_DIR, exist_ok=True)
os.makedirs(PDF_DIR, exist_ok=True)
os.makedirs(TEMP_AUDIO_DIR, exist_ok=True)


app = FastAPI(title="Aura Backend", version="0.1.0")

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "http://127.0.0.1:5173"], # Adjust for your frontend URL
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
async def read_root():
    return {"message": "Welcome to the Aura Backend!"}

# --- Whisper Model Setup ---
# IMPORTANT: Download a Whisper GGML model (e.g., ggml-base.en.bin)
# and place it in the `aura_backend/models/` directory.
# You can find models here: https://huggingface.co/ggerganov/whisper.cpp/tree/main
from whisper_cpp import Whisper

MODEL_DIR = Path("../models")
# Adjust model name as per the file you download
WHISPER_MODEL_PATH = MODEL_DIR / "ggml-base.en.bin" 

if not WHISPER_MODEL_PATH.exists():
    print(f"Whisper model not found at {WHISPER_MODEL_PATH}")
    print("Please download a GGML model and place it in the `aura_backend/models/` directory.")
    # You might want to raise an error or prevent app startup here in a real scenario
    whisper_model = None 
else:
    try:
        whisper_model = Whisper(model_path=str(WHISPER_MODEL_PATH))
        print(f"Whisper model loaded successfully from {WHISPER_MODEL_PATH}")
    except Exception as e:
        print(f"Error loading Whisper model: {e}")
        whisper_model = None

# --- End Whisper Model Setup ---

# --- LLaMA Model Setup ---
# IMPORTANT: Download a GGUF format LLM (e.g., TinyLlama-1.1B-Chat-v1.0.Q4_K_M.gguf)
# and place it in the `aura_backend/models/` directory.
# Models can be found on Hugging Face (e.g., TheBloke search for GGUF).
from llama_cpp import Llama

# Adjust model name as per the file you download. Choose a small, fast model.
# Example: "TinyLlama-1.1B-Chat-v1.0.Q4_K_M.gguf" or similar.
LLAMA_MODEL_FILENAME = "TinyLlama-1.1B-Chat-v1.0.Q4_K_M.gguf" # Replace with your model
LLAMA_MODEL_PATH = MODEL_DIR / LLAMA_MODEL_FILENAME

if not LLAMA_MODEL_PATH.exists():
    print(f"LLaMA model not found at {LLAMA_MODEL_PATH}")
    print(f"Please download a GGUF model file (e.g., {LLAMA_MODEL_FILENAME}) and place it in `aura_backend/models/`.")
    llama_model = None
else:
    try:
        # Adjust n_ctx (context size) and other parameters as needed for your model/task
        # n_gpu_layers > 0 enables GPU offloading if llama-cpp-python was built with GPU support
        llama_model = Llama(
            model_path=str(LLAMA_MODEL_PATH),
            n_ctx=2048, # Context window
            # n_gpu_layers=-1, # Offload all possible layers to GPU. Set to 0 for CPU only.
            verbose=False # Set to True for more LLaMA output
        )
        print(f"LLaMA model loaded successfully from {LLAMA_MODEL_PATH}")
    except Exception as e:
        print(f"Error loading LLaMA model: {e}")
        llama_model = None
# --- End LLaMA Model Setup ---


@app.post("/upload-audio/")
async def upload_audio(file: UploadFile = File(...)):
    if not file.content_type.startswith("audio/"):
        raise HTTPException(status_code=400, detail="Invalid file type. Please upload an audio file.")

    # Ensure filename is safe
    filename = Path(file.filename).name 
    file_location = AUDIO_FILES_DIR / filename
    
    try:
        with open(file_location, "wb+") as file_object:
            shutil.copyfileobj(file.file, file_object)
    except Exception as e:
        # Log the exception e for debugging
        raise HTTPException(status_code=500, detail=f"Could not save file: {e}")
    finally:
        file.file.close()

    return {
        "info": f"File '{filename}' saved at '{file_location.relative_to(DATA_DIR)}'",
        "filename": filename
    }

@app.post("/transcribe/")
async def transcribe_audio(file: UploadFile = File(...)):
    if whisper_model is None:
        raise HTTPException(status_code=503, detail="Whisper model not loaded. Check server logs.")

    if not file.content_type.startswith("audio/"):
        raise HTTPException(status_code=400, detail="Invalid file type. Please upload an audio file.")

    filename_stem = Path(file.filename).stem
    original_suffix = Path(file.filename).suffix
    # Create a unique filename if needed, or simply use the original. For simplicity, using original.
    # Consider adding a timestamp or UUID for uniqueness in a multi-user or high-traffic scenario.
    # e.g., unique_filename = f"{filename_stem}_{int(time.time())}{original_suffix}"
    audio_filename = Path(file.filename).name # Basic sanitization
    audio_file_path = AUDIO_FILES_DIR / audio_filename
    
    transcript_raw_filename = TRANSCRIPTS_DIR / f"{filename_stem}_raw.txt"

    try:
        # Save the audio file permanently
        with open(audio_file_path, "wb+") as audio_file_object:
            shutil.copyfileobj(file.file, audio_file_object)
        
        # Ensure the audio is in a format Whisper can process (e.g., WAV 16kHz mono)
        # This might require an explicit conversion step using ffmpeg if the input isn't right.
        # For now, we assume the input is compatible or whisper_cpp_python handles it.
        
        # Perform transcription using the permanently saved audio file path
        result = whisper_model.transcribe(str(audio_file_path))
        
        transcribed_text = ""
        if isinstance(result, dict) and "text" in result:
            transcribed_text = result["text"]
        elif isinstance(result, list): 
            transcribed_text = " ".join([segment.get("text", "").strip() for segment in result if segment.get("text")])
        elif isinstance(result, str):
             transcribed_text = result
        else:
            print(f"Unexpected Whisper result format: {type(result)}")
            raise HTTPException(status_code=500, detail="Transcription failed or returned unexpected format.")

        # Save the raw transcript
        with open(transcript_raw_filename, "w", encoding="utf-8") as f_raw:
            f_raw.write(transcribed_text)

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error during transcription or saving: {e}")
    finally:
        file.file.close()
        # No temporary file to clean up as we are using the permanent path

    return {"filename": audio_filename, "transcription": transcribed_text, "raw_transcript_path": str(transcript_raw_filename.relative_to(DATA_DIR))}


@app.post("/enhance-text/")
async def enhance_text_endpoint(text_data: dict): # Expecting a JSON with {"text": "some raw text", "original_filename_stem": "filename_without_ext"}
    if llama_model is None:
        raise HTTPException(status_code=503, detail="LLaMA model not loaded. Check server logs.")

    raw_text = text_data.get("text")
    original_filename_stem = text_data.get("original_filename_stem")

    if not raw_text:
        raise HTTPException(status_code=400, detail="No text provided for enhancement.")
    if not original_filename_stem:
        raise HTTPException(status_code=400, detail="Original filename stem not provided for saving enhanced text.")
        
    enhanced_transcript_filename = TRANSCRIPTS_DIR / f"{original_filename_stem}_enhanced.txt"

    # Simple prompt for punctuation and capitalization.
    # This may need significant tuning based on the model.
    # For chat models, you might use a user/assistant turn structure.
    # For base models, a more direct instruction.
    
    # Example for a chat model (like TinyLlama-Chat):
    prompt_template = f"""<|system|>
You are an expert text editor. Please correct the following text by adding appropriate punctuation, fixing capitalization, and ensuring it is well-formatted. Do not change the content or meaning. Output only the corrected text.
</s>
<|user|>
{raw_text}
</s>
<|assistant|>
"""

    try:
        # Parameters for generation:
        # - max_tokens: Max length of the generated text. Adjust based on expected output.
        # - temperature: Controls randomness. Lower is more deterministic (good for this task).
        # - top_p, top_k: Alternative sampling methods.
        # - stop: Sequences that will stop generation.
        # - echo: If True, includes the prompt in the output. We want False.
        
        output = llama_model.create_completion(
            prompt=prompt_template,
            max_tokens=len(raw_text) + 200, # Allow some room for added punctuation etc.
            temperature=0.3, # Low temperature for less creative, more factual correction
            stop=["</s>", "<|user|>"], # Stop generation if model starts new turn
            echo=False
        )
        
        enhanced_text = output['choices'][0]['text'].strip()
        
        # Sometimes models might add prefixes like "Assistant:" or quotes.
        # Basic cleanup, might need to be more robust.
        if enhanced_text.startswith("Assistant:"):
            enhanced_text = enhanced_text[len("Assistant:"):]
        enhanced_text = enhanced_text.strip('" ')

        # Save the enhanced transcript
        with open(enhanced_transcript_filename, "w", encoding="utf-8") as f_enhanced:
            f_enhanced.write(enhanced_text)

    except Exception as e:
        # Log the exception e
        raise HTTPException(status_code=500, detail=f"Error during text enhancement or saving: {e}")

    return {
        "original_text": raw_text,
        "enhanced_text": enhanced_text,
        "enhanced_transcript_path": str(enhanced_transcript_filename.relative_to(DATA_DIR))
    }


if __name__ == "__main__":
    # Note: Adjust host and port as needed. 0.0.0.0 makes it accessible on the network.
    uvicorn.run(app, host="0.0.0.0", port=8000)
