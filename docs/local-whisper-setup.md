# Local Whisper Setup Guide

Complete guide to installing and configuring privacy-first local transcription with whisper.cpp.

## Overview

Local Whisper enables speech-to-clip to transcribe audio entirely on your Mac without sending any data to external servers. This guide walks you through setting up whisper.cpp and configuring speech-to-clip to use it.

**Privacy Guarantee:** When using Local Whisper, your audio never leaves your machine. All processing happens locally.

## Prerequisites

Before you begin, ensure you have:

- **macOS:** Version 14.0 (Sonoma) or later
- **Hardware:** Apple Silicon (M1/M2/M3/M4) strongly recommended for best performance
  - Intel Macs are supported but will be significantly slower
- **Disk Space:** 2-5 GB depending on model size
- **Command Line:** Basic familiarity with Terminal (we'll walk you through each command)
- **speech-to-clip:** Already installed and running

## Quick Start

If you're experienced with command line tools, here's the express version:

```bash
# 1. Install whisper.cpp
git clone https://github.com/ggerganov/whisper.cpp
cd whisper.cpp
cmake -B build
cmake --build build -j

# 2. Download a model
bash ./models/download-ggml-model.sh base

# 3. Start the server
./build/bin/whisper-server -m models/ggml-base.bin

# 4. Configure speech-to-clip
# Open Settings → Profiles → Add Profile
# Select "Local Whisper" engine, enter "base" as model, port 8080

# 5. Test it!
```

For detailed step-by-step instructions, continue reading.

---

## Step 1: Install whisper.cpp

whisper.cpp is the local transcription engine that powers Local Whisper mode.

### Option A: Build from Source (Recommended)

1. **Clone the repository:**
   ```bash
   git clone https://github.com/ggerganov/whisper.cpp
   cd whisper.cpp
   ```

2. **Build whisper.cpp:**
   ```bash
   cmake -B build
   cmake --build build -j
   ```

   This will compile whisper.cpp with optimizations for your Mac. On Apple Silicon, Metal acceleration is automatically enabled for best performance.

3. **Verify installation:**
   ```bash
   ./build/bin/whisper-server -h
   ```

   You should see the help message with server options. If you get an error, ensure you're in the `whisper.cpp` directory and the build completed successfully.

### Option B: Using Homebrew (If Available)

*Note: At the time of writing, whisper.cpp server mode may not be available via Homebrew. Building from source is recommended.*

If a Homebrew formula becomes available:
```bash
brew install whisper-cpp
```

---

## Step 2: Download a Whisper Model

Whisper models come in different sizes. Larger models are more accurate but slower and require more disk space.

### Model Recommendations

| Model | Size | Speed | Best For | Languages |
|-------|------|-------|----------|-----------|
| **tiny** | 75 MB | Very Fast | Quick tests, English only | English |
| **base** | 145 MB | Fast | English, casual use | English, other languages (lower accuracy) |
| **small** | 466 MB | Medium | Good balance for most languages | Multilingual |
| **medium** | 1.5 GB | Slower | **Finnish, Swedish, other non-English** | Multilingual |
| **large** | 3 GB | Slowest | Highest accuracy, all languages | Multilingual |

**Recommendation:**
- **For English:** Start with `base` - fast and accurate
- **For Finnish:** Use `medium` or `large` - significantly better accuracy
- **For other languages:** Start with `small`, upgrade to `medium` if needed

### Download Command

From the `whisper.cpp` directory, run:

```bash
# For English (base model)
bash ./models/download-ggml-model.sh base

# For Finnish (medium model)
bash ./models/download-ggml-model.sh medium

# For highest accuracy (large model)
bash ./models/download-ggml-model.sh large
```

**Expected Output:**
```
Downloading ggml-base.bin ...
ggml-base.bin         100%[===================>] 145.00M  10.2MB/s    in 14s
Model downloaded successfully!
```

The model will be saved to `models/ggml-{model-name}.bin`.

### Disk Space

- tiny: ~75 MB
- base: ~145 MB
- small: ~466 MB
- medium: ~1.5 GB
- large: ~3 GB

---

## Step 3: Start the whisper.cpp Server

The whisper.cpp server runs in the background and provides a local API endpoint that speech-to-clip connects to.

### Basic Server Startup

From the `whisper.cpp` directory:

```bash
./build/bin/whisper-server -m models/ggml-base.bin
```

Replace `base` with your downloaded model (`medium`, `large`, etc.).

**Expected Output:**
```
whisper_init_from_file_with_params_no_state: loading model from 'models/ggml-base.bin'
...
whisper_model_load: model size    =  140.54 MB
...
main: server is listening on http://127.0.0.1:8080
```

✅ When you see "server is listening on http://127.0.0.1:8080", the server is ready!

### Server Options

Customize server behavior with these options:

```bash
# Use different port
./build/bin/whisper-server -m models/ggml-base.bin --port 8081

# Use more CPU threads (adjust based on your CPU cores)
./build/bin/whisper-server -m models/ggml-base.bin -t 4

# Enable Metal acceleration (Apple Silicon - usually auto-detected)
./build/bin/whisper-server -m models/ggml-base.bin -ng 1
```

### Keep Server Running

**Important:** The whisper.cpp server must stay running while using speech-to-clip's Local Whisper mode.

**Option 1: Run in a dedicated Terminal window**
- Keep the Terminal window open
- To stop: Press `Ctrl+C` in the Terminal

**Option 2: Run in background**
```bash
# Start in background
nohup ./build/bin/whisper-server -m models/ggml-base.bin > whisper-server.log 2>&1 &

# Check if running
ps aux | grep "[w]hisper-server"

# Stop server (find PID first with ps command above)
kill <PID>
```

**Option 3: Create a startup script**

Create `start-whisper.sh`:
```bash
#!/bin/bash
cd /path/to/whisper.cpp
./build/bin/whisper-server -m models/ggml-medium.bin --port 8080
```

Make executable and run:
```bash
chmod +x start-whisper.sh
./start-whisper.sh
```

### Verify Server is Running

Test the server with curl:
```bash
curl http://localhost:8080/health
```

Expected response: `OK` or HTTP 200 status.

---

## Step 4: Configure speech-to-clip Profile

Now configure speech-to-clip to use your local whisper.cpp server.

### Create a New Profile

1. **Open speech-to-clip Settings**
   - Click the menu bar icon
   - Select "Settings" (or press `⌘,`)

2. **Navigate to Profiles tab**
   - Click "Profiles" in the settings window

3. **Add a new profile**
   - Click the "+" button or "Add Profile"

4. **Configure the profile:**

   | Field | Value | Notes |
   |-------|-------|-------|
   | **Profile Name** | "Local - English" (or your preference) | Descriptive name to identify this profile |
   | **Transcription Engine** | Select "Local Whisper" | Use dropdown to select Local Whisper |
   | **Model** | `base` (or `medium`, `large`) | Must match the model you downloaded |
   | **Language** | Select your language | e.g., "English" or "Finnish" |
   | **Server Port** | `8080` | Default port; change if you used `--port` |

5. **Save the profile**
   - Click "Save" or "Add"

6. **Activate the profile**
   - Click the profile to make it active
   - Look for a checkmark or highlight indicating it's the active profile

### Profile Configuration Details

**Model Field:** Enter just the model name (`base`, `medium`, `large`), not the full filename.

**Server Port:** Must match the port your whisper.cpp server is running on (default: 8080).

**Language:** Select the primary language you'll be transcribing. This helps the model optimize for that language.

---

## Step 5: Verify It's Working

Test your Local Whisper setup with a sample transcription.

### Test Transcription

1. **Ensure whisper.cpp server is running**
   ```bash
   curl http://localhost:8080/health
   # Should respond with: OK
   ```

2. **Activate your Local Whisper profile**
   - Open Settings → Profiles
   - Select your Local Whisper profile
   - Confirm it's marked as active

3. **Click in a text field**
   - Open any application (TextEdit, Notes, browser, etc.)
   - Click in a text input area

4. **Press your hotkey** (default: `Control+Space`)
   - Watch for the visualizer to appear

5. **Speak clearly** for 3-5 seconds
   - Say something like: "Testing local whisper transcription"

6. **Press hotkey again to stop**

7. **Check the result:**
   - Text should appear in your active text field
   - Also copied to clipboard (press `⌘V` if auto-paste didn't work)

### What to Expect

- **First transcription:** May take 2-5 seconds as the model initializes
- **Subsequent transcriptions:** Should be faster (1-3 seconds)
- **Apple Silicon (M1/M2/M3):** Near real-time transcription
- **Intel Macs:** Slower, may take 5-10 seconds

### Troubleshooting Test

If transcription doesn't work:

1. **Check server is running:**
   ```bash
   curl http://localhost:8080/health
   ```

2. **Check speech-to-clip logs:**
   - Open Console.app
   - Search for "speech-to-clip"
   - Look for error messages

3. **Verify profile settings:**
   - Model name matches downloaded model
   - Port matches server port (8080)
   - Profile is activated (checkmark)

4. **See Troubleshooting section below for common issues**

---

## Troubleshooting

### "Server not running" Error

**Symptom:** Error message says whisper.cpp server is not running or cannot connect.

**Solutions:**
1. Verify server is actually running:
   ```bash
   ps aux | grep "[s]erver"
   ```

2. Check server status:
   ```bash
   curl http://localhost:8080/health
   ```

3. Restart the server:
   ```bash
   cd whisper.cpp
   ./server -m models/ggml-base.bin
   ```

4. Check port conflicts:
   ```bash
   lsof -i :8080
   ```
   If another process is using port 8080, either stop that process or run whisper.cpp on a different port.

### "Connection timeout" Error

**Symptom:** Transcription hangs or times out.

**Solutions:**
1. Check server is responsive:
   ```bash
   curl http://localhost:8080/health
   ```

2. Verify model is loaded correctly (check server output for errors)

3. For large models on slower Macs, increase timeout is expected - wait longer

4. Try a smaller model (`base` instead of `large`) for faster response

### "Model not found" Error

**Symptom:** Server fails to start with "model not found" error.

**Solutions:**
1. Verify model file exists:
   ```bash
   ls -lh models/ggml-*.bin
   ```

2. Ensure model name in profile matches filename:
   - Profile model: `base`
   - File should be: `models/ggml-base.bin`

3. Re-download model if missing:
   ```bash
   bash ./models/download-ggml-model.sh base
   ```

### Poor Transcription Quality

**Symptom:** Transcriptions are inaccurate or garbled.

**Solutions:**
1. **Use a larger model:**
   - For non-English: upgrade from `base` to `medium` or `large`
   - For Finnish: `medium` or `large` strongly recommended

2. **Speak more clearly:**
   - Reduce background noise
   - Speak at normal pace
   - Position microphone closer

3. **Check language setting:**
   - Ensure profile language matches your speech language

4. **Try OpenAI Whisper API:**
   - Create a profile with "OpenAI Whisper" engine for comparison
   - OpenAI's cloud models are often more accurate

### Slow Performance

**Symptom:** Transcriptions take a very long time (>10 seconds).

**Solutions:**
1. **Use smaller model:**
   - Switch from `large` to `medium` or `base`

2. **Check CPU usage:**
   - Open Activity Monitor
   - Look for high CPU usage during transcription
   - If CPU is maxed out, model may be too large for your hardware

3. **Enable Metal acceleration (Apple Silicon):**
   ```bash
   ./server -m models/ggml-base.bin -ng 1
   ```

4. **Reduce threads on older Macs:**
   ```bash
   ./server -m models/ggml-base.bin -t 2
   ```

5. **Consider hardware:**
   - Intel Macs: Local Whisper will be slower - OpenAI API may be better choice
   - Apple Silicon: Should be fast - check for background processes

### Port Conflicts

**Symptom:** Server fails to start with "address already in use" error.

**Solutions:**
1. Find what's using port 8080:
   ```bash
   lsof -i :8080
   ```

2. Option A: Stop the conflicting process:
   ```bash
   kill <PID>
   ```

3. Option B: Use different port:
   ```bash
   ./server -m models/ggml-base.bin --port 8081
   ```
   Then update speech-to-clip profile port to 8081.

---

## Model Performance Comparison

Based on testing on Apple M2 Pro:

| Model | Size | Transcription Speed | Accuracy (English) | Accuracy (Finnish) |
|-------|------|-------------------|-------------------|-------------------|
| tiny | 75 MB | 0.3s per 10s audio | Good | Poor |
| base | 145 MB | 0.5s per 10s audio | Very Good | Fair |
| small | 466 MB | 1.0s per 10s audio | Excellent | Good |
| medium | 1.5 GB | 2.0s per 10s audio | Excellent | Very Good |
| large | 3 GB | 4.0s per 10s audio | Excellent | Excellent |

*Performance varies based on hardware. Intel Macs will be 3-10x slower.*

---

## Advanced Configuration

### Multiple Models

You can switch between models by creating multiple profiles:

1. Download multiple models:
   ```bash
   bash ./models/download-ggml-model.sh base
   bash ./models/download-ggml-model.sh medium
   ```

2. Run server with one model at a time

3. Create separate profiles:
   - "Local - English (Fast)" → model: `base`
   - "Local - Finnish (Accurate)" → model: `medium`

4. Switch profiles in speech-to-clip Settings

**Note:** You must restart the server to change models. The model is loaded at server startup.

### Server Optimization Flags

```bash
# Maximum performance on Apple Silicon
./build/bin/whisper-server -m models/ggml-base.bin -ng 1 -t 4

# Low memory usage
./build/bin/whisper-server -m models/ggml-base.bin -t 2

# Verbose logging for debugging
./build/bin/whisper-server -m models/ggml-base.bin -v
```

### Auto-start Server at Login

Create a LaunchAgent to start whisper.cpp automatically:

1. Create `~/Library/LaunchAgents/com.whisper.server.plist`:
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
       <key>Label</key>
       <string>com.whisper.server</string>
       <key>ProgramArguments</key>
       <array>
           <string>/path/to/whisper.cpp/server</string>
           <string>-m</string>
           <string>/path/to/whisper.cpp/models/ggml-medium.bin</string>
       </array>
       <key>RunAtLoad</key>
       <true/>
       <key>KeepAlive</key>
       <true/>
       <key>StandardOutPath</key>
       <string>/tmp/whisper-server.log</string>
       <key>StandardErrorPath</key>
       <string>/tmp/whisper-server-error.log</string>
   </dict>
   </plist>
   ```

2. Load the agent:
   ```bash
   launchctl load ~/Library/LaunchAgents/com.whisper.server.plist
   ```

3. Verify it's running:
   ```bash
   launchctl list | grep whisper
   curl http://localhost:8080/health
   ```

---

## Further Reading

### Official Documentation

- **whisper.cpp Repository:** https://github.com/ggerganov/whisper.cpp
- **whisper.cpp Server Mode:** https://github.com/ggerganov/whisper.cpp#server
- **OpenAI Whisper (Research):** https://github.com/openai/whisper

### speech-to-clip Documentation

- **Architecture Document:** [Local Whisper Architecture](architecture-localwhisper.md) - Technical details about how the integration works
- **Main README:** [../README.md](../README.md) - speech-to-clip overview and features

### Community & Support

- **whisper.cpp Issues:** https://github.com/ggerganov/whisper.cpp/issues
- **speech-to-clip Issues:** https://github.com/Latentti/speech-to-clip/issues

---

## Privacy & Security

### Privacy Guarantee

When using Local Whisper mode in speech-to-clip:

✅ **Audio never leaves your Mac** - All processing is local
✅ **No internet connection required** - Works completely offline
✅ **No telemetry or analytics** - Your data stays on your machine
✅ **No API keys needed** - Free and private

### How to Verify

You can verify that no network calls are made:

1. **Use network monitoring tools:**
   - Little Snitch (commercial)
   - Wireshark (open source)
   - macOS Network Utility

2. **Check speech-to-clip only connects to localhost:**
   ```bash
   # While transcribing with Local Whisper:
   lsof -i -n | grep speech-to-clip
   # Should only show connections to 127.0.0.1:8080 (localhost)
   ```

3. **Review the code:**
   - speech-to-clip is open source
   - WhisperCppClient.swift validates localhost-only URLs
   - See [architecture document](architecture-localwhisper.md) for details

### Comparison: Local Whisper vs OpenAI API

| Aspect | Local Whisper | OpenAI Whisper API |
|--------|--------------|-------------------|
| **Privacy** | 🔒 Audio never leaves Mac | ⚠️ Audio sent to OpenAI servers |
| **Cost** | ✅ Free | 💰 $0.006 per minute |
| **Internet** | ✅ Works offline | ❌ Requires internet |
| **Speed** | ⚡ Fast on Apple Silicon, slow on Intel | ⚡ Fast (cloud processing) |
| **Accuracy** | ⭐⭐⭐⭐ Very good (model-dependent) | ⭐⭐⭐⭐⭐ Excellent |
| **Languages** | ✅ All languages | ✅ All languages |
| **Setup** | ⚙️ Manual setup required | ✅ Just add API key |

**Use Local Whisper when:**
- Privacy is critical
- Working with sensitive information
- No internet access
- Want to avoid API costs
- Have Apple Silicon Mac

**Use OpenAI API when:**
- Maximum accuracy needed
- Convenience is priority
- Intel Mac (slow local processing)
- Don't want to manage server

---

## Summary

You've successfully set up Local Whisper! Here's what you accomplished:

✅ Installed whisper.cpp
✅ Downloaded a Whisper model
✅ Started the local server
✅ Configured speech-to-clip profile
✅ Tested transcription

**Remember:**
- Keep the whisper.cpp server running while using speech-to-clip
- You can switch between Local Whisper and OpenAI profiles anytime
- Larger models = better accuracy but slower speed
- Your audio never leaves your Mac when using Local Whisper

Enjoy privacy-first speech-to-text! 🎤🔒
