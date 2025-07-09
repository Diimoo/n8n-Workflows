**Komplettanleitung: Vollautomatischer Video-Workflow mit n8n, lokalem LLM, TTS, FFmpeg und Upload auf YouTube/TikTok**

---

### 🚀 Vorbereitung: n8n-Umgebung einrichten

**1. Terminal öffnen und folgendes eingeben:**

```bash
docker run -it --name n8n -p 5678:5678 -v ~/.n8n:/home/node/.n8n n8nio/n8n
sudo apt update && sudo apt install -y ffmpeg python3 python3-pip
```

**2. n8n Weboberfläche aufrufen:**

* Im Browser: `http://localhost:5678`

---

### 📂 Schritt 1: Webscraping eines Reddit-Posts

**1. In n8n: Workflow erstellen > Erster Node: HTTP Request**

* **Node-Name:** Reddit Fetch
* **Methode:** `GET`
* **URL:** z. B. `https://www.reddit.com/r/AITA/top.json?limit=1&t=day`
* **Response Format:** `JSON`

**2. HTML oder JSON Text extrahieren:**

* **Node:** Function
* **Code:**

```javascript
return [{ json: { title: $json.data.children[0].data.title, text: $json.data.children[0].data.selftext }}];
```

---

### 🤖 Schritt 2: Text umschreiben mit lokalem LLM (z. B. über Ollama)

**1. Ollama installieren und starten:**

```bash
curl -fsSL https://ollama.com/install.sh | sh
ollama run mistral:instruct
```

**2. In n8n: HTTP Request-Node für LLM**

* **Methode:** `POST`
* **URL:** `http://localhost:11434/api/generate`
* **Body Content-Type:** `RAW > JSON`
* **Body:**

```json
{
  "model": "mistral:instruct",
  "prompt": "Schreibe den folgenden Reddit-Post wie eine spannende Kurzgeschichte um:\n{{$json["text"]}}",
  "stream": false
}
```

* **Result:** Die umgeschriebene Story ist im Feld `response` enthalten.

---

### 🎙️ Schritt 3: Text-to-Speech mit Kokoro TTS (offline, kostenlos)

**1. Kokoro TTS clonen & installieren:**

```bash
git clone https://github.com/Plachtaa/Kokoro-Voice.git
cd Kokoro-Voice
pip3 install -r requirements.txt
python3 app.py  # Startet lokalen Server auf http://localhost:7860
```

**2. Python-Skript erstellen: `/home/user/voicegen.py`**

```python
from gradio_client import Client
import sys

text = sys.argv[1]
voice = "af_sarah"
client = Client("http://localhost:7860")
result = client.predict(text, voice, 1.0, api_name="/generate_speech")
```

**3. In n8n: Execute Command Node**

* **Command:** `python3`
* **Args:** `/home/user/voicegen.py "{{$json["response"]}}"`
* **Output-Audio-Datei:** z. B. `/tmp/output.mp3`

---

### 🎥 Schritt 4: Video erstellen mit FFmpeg

**1. Lange Videos vorbereiten:**

* z. B. `/home/user/videos/minecraft.mp4`

**2. In n8n: Execute Command Node**

* **Command:** `ffmpeg`
* **Args:**

```bash
-i /home/user/videos/minecraft.mp4 -i /tmp/output.mp3 -shortest -c:v libx264 -preset veryfast -c:a aac -b:a 192k -y /tmp/final_video.mp4
```

**Optional:** Hochformat erzwingen mit `-vf` Parameter.

---

### ✍️ Schritt 5: Untertitel erzeugen (optional, empfohlen)

**1. Whisper installieren (GPU-Version):**

```bash
pip3 install git+https://github.com/openai/whisper.git
```

**2. In n8n: Execute Command Node**

* **Command:** `whisper`
* **Args:** `/tmp/output.mp3 --model medium --output_format srt --output_dir /tmp`
* **Ergebnis:** `/tmp/output.srt`

**3. Finales Video mit Untertiteln:**

```bash
ffmpeg -i /tmp/final_video.mp4 -vf "subtitles=/tmp/output.srt" -c:a copy -y /tmp/final_video_sub.mp4
```

---

### 📄 Schritt 6: YouTube Upload (mit OAuth2)

**1. Google Cloud Console:**

* Projekt erstellen > YouTube Data API v3 aktivieren
* OAuth2 Credentials erstellen (Typ: Desktop/Web)
* In n8n unter Credentials > YouTube API > Client ID & Secret eintragen

**2. In n8n: YouTube Node**

* **Operation:** Upload Video
* **Binary File:** `/tmp/final_video_sub.mp4`
* **Titel/Beschreibung:** aus vorherigem Text oder manuell

---

### 📺 Schritt 7: TikTok Upload (komplizierter)

**1. TikTok Developer-Konto:**

* [https://developers.tiktok.com](https://developers.tiktok.com) > App erstellen > "Content Posting API" aktivieren

**2. OAuth2 Flow manuell oder via Community Node**

* Upload erfolgt über multipart API Upload (siehe TikTok Docs)
* Alternativ Puppeteer Headless Upload (nicht offiziell, aber praktikabel)

---

### ⌛ Abschließend

**Workflow speichern und testen**
**n8n Workflow aktivieren: Zeittrigger, Cron, oder manuell**

Glückwunsch, du hast jetzt ein vollautomatisiertes System: Reddit-Post → LLM Rewrite → Voiceover → Video mit Untertiteln → Upload!
