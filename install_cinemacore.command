#!/bin/bash

# 
==============================================================================
# CinemaCore AI - All-in-One Automated macOS Installer & Packager
# 
==============================================================================

set -e

echo "========================================================"
echo "      🚀 Installing CinemaCore AI for Premiere Pro      "
echo "========================================================"

# 1. Define Target Directories
EXT_DIR="$HOME/Library/Application 
Support/Adobe/CEP/extensions/CinemaCore"
BACKEND_DIR="$HOME/Library/Application Support/CinemaCore_Backend"
DESKTOP_DIR="$HOME/Desktop"

echo "[-] Creating extension directories..."
mkdir -p "$EXT_DIR/CSXS"
mkdir -p "$EXT_DIR/js"
mkdir -p "$EXT_DIR/jsx"
mkdir -p "$BACKEND_DIR"

# 2. Enable Adobe Debug Mode (Bypasses Extension Signing Check)
echo "[-] Configuring Adobe PlayerDebugMode for all CC versions..."
for v in 9 10 11 12 13 14 15 16; do
    defaults write com.adobe.CSXS.$v PlayerDebugMode 1 2>/dev/null || true
done

# 3. Download / Install CSInterface.js
echo "[-] Fetching Adobe CSInterface library..."
curl -s -L 
"https://raw.githubusercontent.com/Adobe-CEP/CEP-Resources/master/CEP_11.x/CSInterface.js" 
-o "$EXT_DIR/js/CSInterface.js" || {
    echo "[!] Fallback: Creating minimal CSInterface..."
    cat << 'EOF' > "$EXT_DIR/js/CSInterface.js"
function CSInterface() {}
CSInterface.prototype.evalScript = function(script, callback) {
    if (window.__adobe_cep__) {
        window.__adobe_cep__.evalScript(script, callback);
    }
};
EOF
}

# 4. Write manifest.xml
echo "[-] Writing CSXS/manifest.xml..."
cat << 'EOF' > "$EXT_DIR/CSXS/manifest.xml"
<?xml version="1.0" encoding="UTF-8"?>
<ExtensionManifest Version="9.0" ExtensionBundleId="com.cinemacore.aiedit" 
ExtensionBundleVersion="1.0" ExtensionBundleName="CinemaCore AI" 
xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <ExtensionList>
        <Extension Id="com.cinemacore.aiedit.panel" Version="1.0" />
    </ExtensionList>
    <ExecutionEnvironment>
        <HostList>
            <Host Name="PPRO" Version="11.0" />
        </HostList>
        <LocaleList>
            <Locale Code="All" />
        </LocaleList>
        <RequiredRuntimeList>
            <RequiredRuntime Name="CSXS" Version="9.0" />
        </RequiredRuntimeList>
    </ExecutionEnvironment>
    <DispatchInfoList>
        <Extension Id="com.cinemacore.aiedit.panel">
            <DispatchInfo>
                <Resources>
                    <MainPath>./index.html</MainPath>
                    <ScriptPath>./jsx/CinemaCoreAI.jsx</ScriptPath>
                </Resources>
                <Lifecycle>
                    <AutoVisible>true</AutoVisible>
                </Lifecycle>
                <UI>
                    <Type>Panel</Type>
                    <Menu>CinemaCore AI Assistant</Menu>
                    <Geometry>
                        <Size>
                            <Height>520</Height>
                            <Width>420</Width>
                        </Size>
                    </Geometry>
                </UI>
            </DispatchInfo>
        </Extension>
    </DispatchInfoList>
</ExtensionManifest>
EOF

# 5. Write index.html
echo "[-] Writing index.html..."
cat << 'EOF' > "$EXT_DIR/index.html"
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>CinemaCore AI</title>
    <style>
        body { background-color: #1e1e1e; color: #ececec; font-family: 
-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; 
padding: 18px; margin: 0; }
        h3 { font-size: 13px; text-transform: uppercase; letter-spacing: 
1px; color: #00b4d8; margin: 12px 0 6px 0; }
        textarea { width: 100%; height: 130px; background: #121212; color: 
#fff; border: 1px solid #333; border-radius: 6px; padding: 10px; 
box-sizing: border-box; resize: vertical; font-size: 12px; }
        input[type="text"] { width: 100%; background: #121212; color: 
#fff; border: 1px solid #333; border-radius: 6px; padding: 9px; 
box-sizing: border-box; font-size: 12px; }
        button { background: #0077b6; color: #fff; border: none; padding: 
12px; width: 100%; border-radius: 6px; font-weight: 600; cursor: pointer; 
margin-top: 15px; transition: 0.2s; font-size: 13px; }
        button:hover { background: #0096c7; }
        #status { margin-top: 15px; font-size: 12px; color: #90e0ef; 
line-height: 1.4; }
    </style>
</head>
<body>
    <h3>1. Scene Script / Story Beat</h3>
    <textarea id="scriptInput" placeholder="Paste dialogue/action lines in 
English or Tamil..."></textarea>

    <h3>2. Target Premiere Bin</h3>
    <input type="text" id="binInput" placeholder="e.g. RAW FOOTAGE (Leave 
empty for root)" />

    <button id="btnAnalyze">Run CinemaCore Auto-Cut</button>
    <div id="status">Status: Engine Standby</div>

    <script src="./js/CSInterface.js"></script>
    <script src="./js/main.js"></script>
</body>
</html>
EOF

# 6. Write js/main.js
echo "[-] Writing js/main.js..."
cat << 'EOF' > "$EXT_DIR/js/main.js"
const csInterface = new CSInterface();

document.getElementById('btnAnalyze').addEventListener('click', () => {
    const scriptText = 
document.getElementById('scriptInput').value.trim();
    const binName = document.getElementById('binInput').value.trim() || 
"Root";
    const statusEl = document.getElementById('status');

    if (!scriptText) {
        statusEl.innerText = "Status: Please enter scene script or 
narrative logline.";
        return;
    }

    statusEl.innerText = "Status: Scanning Premiere Pro media bins...";

    const command = `CinemaCoreAI.exportBinToAI("${binName}")`;
    csInterface.evalScript(command, (result) => {
        let premiereData;
        try {
            premiereData = JSON.parse(result);
        } catch(e) {
            statusEl.innerText = "Status: Error evaluating project items: 
" + result;
            return;
        }

        if (premiereData.error) {
            statusEl.innerText = "Status Error: " + premiereData.error;
            return;
        }

        statusEl.innerText = `Status: Sending ${premiereData.total_clips} 
clips to local AI engine...`;
        premiereData.script_text = scriptText;

        fetch('http://127.0.0.1:8000/process-clips', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(premiereData)
        })
        .then(res => res.json())
        .then(data => {
            statusEl.innerText = "Status: AI Analysis & Proxy pass running 
in background. Check terminal for live cut generation!";
        })
        .catch(err => {
            statusEl.innerText = "Status: Backend connection failed. 
Ensure the 'CinemaCore AI Server' terminal is running.";
        });
    });
});
EOF

# 7. Write jsx/CinemaCoreAI.jsx
echo "[-] Writing jsx/CinemaCoreAI.jsx..."
cat << 'EOF' > "$EXT_DIR/jsx/CinemaCoreAI.jsx"
var CinemaCoreAI = (function() {
    function findBinByName(parentItem, targetBinName) {
        if (parentItem.name === targetBinName && parentItem.type === 
ProjectItemType.BIN) {
            return parentItem;
        }
        for (var i = 0; i < parentItem.children.numItems; i++) {
            var child = parentItem.children[i];
            if (child.type === ProjectItemType.BIN) {
                var found = findBinByName(child, targetBinName);
                if (found) return found;
            }
        }
        return null;
    }

    function extractClips(binItem) {
        var clips = [];
        for (var i = 0; i < binItem.children.numItems; i++) {
            var item = binItem.children[i];
            if (item.type === ProjectItemType.CLIP) {
                var mediaPath = item.getMediaPath();
                if (mediaPath) {
                    clips.push({
                        clip_name: item.name,
                        file_path: mediaPath,
                        duration_seconds: item.getDuration().seconds,
                        has_video: item.hasVideo(),
                        has_audio: item.hasAudio(),
                        frame_rate: item.getVideoFrameRate(),
                        node_id: item.nodeId
                    });
                }
            } else if (item.type === ProjectItemType.BIN) {
                clips = clips.concat(extractClips(item));
            }
        }
        return clips;
    }

    return {
        exportBinToAI: function(binName) {
            try {
                if (typeof JSON !== 'object') { app.enableQE(); }
                var project = app.project;
                if (!project) return JSON.stringify({ error: "No active 
project found." });

                var searchTarget = (binName && binName !== "Root") ? 
findBinByName(project.rootItem, binName) : project.rootItem;
                if (!searchTarget) return JSON.stringify({ error: "Bin '" 
+ binName + "' not found." });

                var clipData = extractClips(searchTarget);
                return JSON.stringify({
                    success: true,
                    bin_analyzed: binName || "Root",
                    total_clips: clipData.length,
                    clips: clipData
                });
            } catch (error) {
                return JSON.stringify({ error: error.toString() });
            }
        }
    };
})();
EOF

# 8. Write Python Backend Files
echo "[-] Writing Python AI engine..."
cat << 'EOF' > "$BACKEND_DIR/ai_brain.py"
import os
import time
from pydantic import BaseModel
from google import genai
from google.genai import types

class CutDecision(BaseModel):
    clip_name: str
    file_path: str
    in_point_seconds: float
    out_point_seconds: float
    reasoning: str 

class TimelineAssembly(BaseModel):
    sequence_name: str
    cuts: list[CutDecision]

def generate_ai_edit(script_text: str, ai_ready_data: list):
    client = genai.Client()
    uploaded_files = []
    
    print("\n[CinemaCore Brain] Uploading low-res video proxies to Gemini 
1.5 Pro...")
    for media in ai_ready_data:
        gemini_file = client.files.upload(file=media["proxy_file"])
        while gemini_file.state.name == "PROCESSING":
            time.sleep(2)
            gemini_file = client.files.get(name=gemini_file.name)
            
        uploaded_files.append({
            "gemini_file_obj": gemini_file,
            "original_file": media["original_file"],
            "clip_name": os.path.basename(media["original_file"]),
            "transcript": media["transcript_with_timecodes"]
        })

    prompt = f"""
    SYSTEM ROLE: You are 'CinemaCore,' an elite Master-Level Film Editor.
    
    OBJECTIVE: Analyze the proxy footage, Whisper dialogue timestamps, and 
the provided screenplay/scene beats.
    Pick the highest-quality takes (emotional delivery, natural cadence, 
sharp focus) and remove false takes, camera resets, and director calls.
    
    SCENE SCRIPT:
    {script_text}
    
    FOOTAGE & TIMESTAMPS:
    {[{'file': u['original_file'], 'transcript': u['transcript']} for u in 
uploaded_files]}
    
    OUTPUT: Return a frame-accurate sequential timeline array with precise 
IN/OUT seconds.
    """

    print("[CinemaCore Brain] Evaluating takes and composing cinematic 
assembly...")
    contents = [prompt] + [u["gemini_file_obj"] for u in uploaded_files]

    response = client.models.generate_content(
        model='gemini-1.5-pro',
        contents=contents,
        config=types.GenerateContentConfig(
            response_mime_type="application/json",
            response_schema=TimelineAssembly,
            temperature=0.2 
        ),
    )

    assembly_data = response.parsed
    output_xml = 
os.path.expanduser("~/Desktop/CinemaCore_Output_Sequence.xml")
    build_fcp_xml(assembly_data, output_xml)

def build_fcp_xml(assembly_data: TimelineAssembly, output_filename):
    fps = 24 
    xml_header = f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE xmeml>
<xmeml version="4">
  <project>
    <name>CinemaCore Assembly</name>
    <children>
      <sequence id="cinemacore-seq">
        <name>{assembly_data.sequence_name}</name>
        <rate><timebase>{fps}</timebase><ntsc>FALSE</ntsc></rate>
        <media><video><format>
            
<samplecharacteristics><width>1920</width><height>1080</height></samplecharacteristics>
        </format><track>"""
            
    xml_footer = 
"""</track></video></media></sequence></children></project></xmeml>"""
    xml_clips = ""
    current_timeline_frame = 0

    for index, cut in enumerate(assembly_data.cuts):
        print(f" -> Selected: {cut.clip_name} [{cut.in_point_seconds:.2f}s 
- {cut.out_point_seconds:.2f}s] | Reason: {cut.reasoning}")
        in_frame = int(cut.in_point_seconds * fps)
        out_frame = int(cut.out_point_seconds * fps)
        duration = out_frame - in_frame
        end_timeline_frame = current_timeline_frame + duration

        xml_clips += f"""
              <clipitem id="clipitem-{index}">
                <name>{cut.clip_name}</name>
                <rate><timebase>{fps}</timebase></rate>
                <in>{in_frame}</in>
                <out>{out_frame}</out>
                <start>{current_timeline_frame}</start>
                <end>{end_timeline_frame}</end>
                <file id="file-{index}">
                  <name>{cut.clip_name}</name>
                  <pathurl>file://{cut.file_path.replace(' ', 
'%20')}</pathurl>
                </file>
              </clipitem>"""
        current_timeline_frame = end_timeline_frame

    with open(output_filename, "w", encoding="utf-8") as f:
        f.write(xml_header + xml_clips + xml_footer)
        
    print(f"\n[DONE] 🎉 Master XML created on your Desktop: 
{output_filename}")
    print("Drag and drop this XML file into Premiere Pro to load your AI 
cut.")
EOF

cat << 'EOF' > "$BACKEND_DIR/engine.py"
import os
import subprocess
import whisper
from fastapi import FastAPI, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List
from ai_brain import generate_ai_edit

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

print("[Engine] Loading Whisper transcription model...")
audio_model = whisper.load_model("base")

class ClipItem(BaseModel):
    clip_name: str
    file_path: str
    has_video: bool
    has_audio: bool

class PremiereData(BaseModel):
    script_text: str
    clips: List[ClipItem]

def generate_proxy(input_path: str, output_path: str):
    if not os.path.exists(output_path):
        subprocess.run([
            "ffmpeg", "-y", "-i", input_path, "-vf", "scale=-2:480", 
            "-c:v", "libx264", "-crf", "28", "-preset", "superfast", 
            "-c:a", "aac", "-b:a", "128k", output_path
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return output_path

def process_media_pipeline(data: PremiereData):
    workspace_dir = os.path.expanduser("~/Library/Application 
Support/CinemaCore_Backend/workspace")
    os.makedirs(workspace_dir, exist_ok=True)
    ai_ready_data = []

    print(f"\n[Engine] Ingesting {len(data.clips)} clips from 
Premiere...")
    for clip in data.clips:
        safe_name = 
os.path.splitext(os.path.basename(clip.file_path))[0].replace(" ", "_")
        proxy_path = os.path.join(workspace_dir, f"{safe_name}_proxy.mp4")
        
        if clip.has_video:
            generate_proxy(clip.file_path, proxy_path)
            
        transcript = []
        if clip.has_audio:
            result = audio_model.transcribe(clip.file_path, 
word_timestamps=True)
            for seg in result.get("segments", []):
                transcript.append({"start": seg["start"], "end": 
seg["end"], "text": seg["text"]})
                
        ai_ready_data.append({
            "original_file": clip.file_path,
            "proxy_file": proxy_path if clip.has_video else 
clip.file_path,
            "transcript_with_timecodes": transcript
        })
        
    generate_ai_edit(data.script_text, ai_ready_data)

@app.post("/process-clips")
async def receive_clips_from_premiere(data: PremiereData, 
background_tasks: BackgroundTasks):
    background_tasks.add_task(process_media_pipeline, data)
    return {"status": "processing"}
EOF

# 9. Set Up Python Virtual Environment
echo "[-] Creating isolated Python virtual environment..."
python3 -m venv "$BACKEND_DIR/venv"
source "$BACKEND_DIR/venv/bin/activate"

echo "[-] Installing AI dependencies (FastAPI, Whisper, Google GenAI 
SDK)..."
pip install --upgrade pip --quiet
pip install fastapi uvicorn openai-whisper pydantic google-genai --quiet

# 10. Create 1-Click Desktop Launcher
echo "[-] Creating Desktop Launcher..."
cat << EOF > "$DESKTOP_DIR/Start CinemaCore AI Server.command"
#!/bin/bash
clear
echo "========================================================"
echo "           🎬 CinemaCore AI Backend Server              "
echo "========================================================"

if [ -z "\$GEMINI_API_KEY" ]; then
    echo ""
    read -p "Enter your Google Gemini API Key: " user_key
    export GEMINI_API_KEY="\$user_key"
fi

source "$BACKEND_DIR/venv/bin/activate"
cd "$BACKEND_DIR"

echo ""
echo "[*] Server is active on http://127.0.0.1:8000"
echo "[*] Open Premiere Pro -> Window -> Extensions -> CinemaCore AI 
Assistant"
echo ""

uvicorn engine:app --host 127.0.0.1 --port 8000
EOF

chmod +x "$DESKTOP_DIR/Start CinemaCore AI Server.command"

echo ""
echo "========================================================"
echo "  ✅ INSTALLATION COMPLETE!                             "
echo "========================================================"
echo "1. Double-click 'Start CinemaCore AI Server.command' on your 
Desktop."
echo "2. Launch Premiere Pro."
echo "3. Go to Window > Extensions > CinemaCore AI Assistant."
echo "========================================================"
