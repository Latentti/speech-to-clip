# Privacy Guarantees - Local Whisper

Your privacy matters. When using Local Whisper mode in speech-to-clip, your audio data **never leaves your Mac**. This document explains our privacy guarantees, how to verify them, and how you can audit the code yourself.

## The Guarantee

🔒 **When using Local Whisper, your audio stays on your machine. Period.**

- ✅ **Zero external network calls** - All processing happens locally
- ✅ **Zero telemetry** - No usage statistics collected
- ✅ **Zero analytics** - No tracking or monitoring
- ✅ **Zero cloud services** - No API calls to external servers
- ✅ **Complete offline capability** - Works without internet

All transcription happens on your Mac using whisper.cpp running on `localhost:8080`. No exceptions.

## How It Works

Local Whisper uses a **localhost-only architecture**:

1. **You speak** → speech-to-clip captures audio
2. **Audio sent to whisper.cpp** → Via `http://127.0.0.1:8080` (localhost only)
3. **Whisper processes locally** → On your Mac's CPU/GPU
4. **Transcription returned** → Via localhost
5. **Text placed in clipboard** → Ready to use

**No external network connection at any step.**

## Verification

Don't just trust us—verify our claims yourself.

### Automated Privacy Tests

We include automated privacy verification tests that run on every commit:

**Test File:** [`speech-to-clipTests/CoreTests/Transcription/WhisperCppClientTests.swift`](../../speech-to-clipTests/CoreTests/Transcription/WhisperCppClientTests.swift)

**Key Tests:**
- `testHealthCheckValidatesLocalhostOnly()` - Ensures only localhost URLs accepted
- `testTranscribeRejectsNonLocalhostURLs()` - Blocks any non-localhost connections
- Tests **fail the build** if ANY external network call detected

**Run tests yourself:**
```bash
cd speech-to-clip
xcodebuild test -scheme "speech-to-clip" -destination 'platform=macOS'
```

All tests must pass before any code is merged. Privacy is enforced by our continuous integration pipeline.

### Manual Network Monitoring

You can verify privacy yourself using network monitoring tools:

#### Option 1: Little Snitch (Recommended)

[Little Snitch](https://www.obdev.at/products/littlesnitch/) is a popular macOS firewall that shows all network connections.

1. Install Little Snitch
2. Set to "Silent Mode - Alert"
3. Use speech-to-clip with Local Whisper profile
4. **Verify:** Only `127.0.0.1:8080` connections appear
5. **No connections to external hosts should appear**

#### Option 2: Activity Monitor (Built-in)

1. Open **Activity Monitor** (Applications → Utilities)
2. Click **Network** tab
3. Find `speech-to-clip` process
4. Monitor "Sent Bytes" and "Received Bytes"
5. **Result:** Should only show localhost traffic when transcribing

#### Option 3: lsof Command (Advanced)

Monitor active connections in real-time:

```bash
# Monitor speech-to-clip network connections
lsof -i -n -P | grep speech-to-clip

# During Local Whisper transcription, you should only see:
# speech-to-clip ... TCP 127.0.0.1:xxxxx->127.0.0.1:8080 (ESTABLISHED)
```

**Expected result:** Only connections to `127.0.0.1` (localhost). No external IP addresses.

## Code Audit

Speech-to-Clip is **100% open source**. You can audit every line of code.

### Key Files to Review

**Whisper Client Implementation:**
- [`Core/Transcription/WhisperCppClient.swift`](../../Core/Transcription/WhisperCppClient.swift)
  - See `healthCheck()` method - validates localhost-only URLs
  - See `transcribe()` method - only accepts localhost connections
  - URL validation prevents any external network calls

**Privacy Tests:**
- [`speech-to-clipTests/CoreTests/Transcription/WhisperCppClientTests.swift`](../../speech-to-clipTests/CoreTests/Transcription/WhisperCppClientTests.swift)
  - Automated verification of privacy guarantees
  - Tests run on every code change

### How to Audit the Code

**1. Clone the repository:**
```bash
git clone https://github.com/Latentti/speech-to-clip.git
cd speech-to-clip/speech-to-clip
```

**2. Search for network-related code:**
```bash
# Find all URL constructions
grep -r "URL(string:" speech-to-clip/

# Find URLSession usage
grep -r "URLSession" speech-to-clip/

# Verify localhost-only validation
grep -r "localhost\|127.0.0.1" speech-to-clip/Core/Transcription/
```

**3. Review URL validation logic:**

Open `Core/Transcription/WhisperCppClient.swift` and look for the health check method. You'll see URL validation that **only accepts** `http://127.0.0.1` or `http://localhost`.

**4. Run the tests:**
```bash
xcodebuild test -scheme "speech-to-clip"
```

All privacy tests must pass. If they fail, the code cannot be merged.

## Local Whisper vs OpenAI API

Both transcription options are legitimate choices. Pick based on your needs:

| Feature | 🔒 Local Whisper | ☁️ OpenAI API |
|---------|-----------------|--------------|
| **Privacy** | ✅ Audio never leaves Mac | ⚠️ Audio sent to OpenAI servers |
| **Network** | ✅ Localhost only (127.0.0.1:8080) | ❌ Internet required |
| **Offline** | ✅ Works completely offline | ❌ Requires internet connection |
| **API Key** | ✅ Not needed | ❌ Required (paid service) |
| **Cost** | ✅ Free | 💰 $0.006 per minute |
| **Speed** | ⚡ Fast on Apple Silicon | 🌐 Depends on network latency |
| **Accuracy** | ⭐⭐⭐⭐ Very good (model-dependent) | ⭐⭐⭐⭐⭐ Excellent |
| **Setup** | ⚙️ Manual setup required | ✅ Just add API key |
| **Data Control** | ✅ You control everything | ⚠️ Data processed by OpenAI |

### Use Local Whisper when:
- Privacy is critical
- Working with sensitive information
- No internet access available
- Want to avoid API costs
- Have Apple Silicon Mac (M1/M2/M3/M4)

### Use OpenAI API when:
- Maximum accuracy is required
- Convenience is priority
- Have reliable internet
- Intel Mac (slower local processing)
- Don't want to manage local server

## Architecture Details

For technical implementation details, see:
- [Local Whisper Architecture](architecture-localwhisper.md) - Complete technical design
- [Local Whisper Setup Guide](local-whisper-setup.md) - Installation and configuration

## Open Source Transparency

**Speech-to-Clip is open source.** No hidden network calls. No proprietary transcription services. Every line of code is public and auditable.

**Repository:** https://github.com/Latentti/speech-to-clip

We invite the security community to:
- ✅ Review the code
- ✅ Run the privacy tests
- ✅ Monitor network traffic
- ✅ Report any concerns
- ✅ Submit improvements

Found a privacy concern? [Open an issue](https://github.com/Latentti/speech-to-clip/issues) immediately.

## What We DON'T Collect

When using Local Whisper mode:

- ❌ No audio data sent externally
- ❌ No transcription text sent externally
- ❌ No telemetry or analytics
- ❌ No crash reports (unless you opt-in for general app crashes)
- ❌ No usage statistics
- ❌ No personal data transmitted
- ❌ No tracking cookies or identifiers

**We literally cannot collect this data—the code doesn't support it.** Localhost-only architecture means there's nowhere for data to go.

## Privacy vs Security

**Privacy** (what we guarantee):
- Your data stays local
- No external transmission
- No cloud processing

**Security** (additional considerations):
- Keep your Mac's OS updated
- Use FileVault disk encryption
- Secure your whisper.cpp installation
- Review user permissions regularly

Privacy means your data doesn't leave. Security means your data is protected from unauthorized access. We guarantee privacy; you control security.

## Trust, But Verify

We encourage you to verify our privacy claims:

1. ✅ **Read the source code** - It's all public
2. ✅ **Run the tests** - Privacy tests must pass
3. ✅ **Monitor network traffic** - Use Little Snitch or lsof
4. ✅ **Ask questions** - Open GitHub issues
5. ✅ **Report concerns** - We take privacy seriously

**Privacy is not a marketing feature—it's a fundamental right.**

---

## Frequently Asked Questions

**Q: Can you add analytics later without me knowing?**
A: No. The code is open source. Any analytics would be visible in the code and caught by privacy tests. Updates are transparent via GitHub.

**Q: Does whisper.cpp itself send data externally?**
A: No. whisper.cpp runs entirely locally. It's an offline transcription engine with no network capabilities.

**Q: What if I use both Local Whisper and OpenAI API?**
A: Privacy guarantees apply only when Local Whisper is the active profile. When using OpenAI API, audio is sent to OpenAI's servers per their API terms.

**Q: How do I know which mode I'm using?**
A: Check your active profile in Settings → Profiles. The transcription engine is clearly displayed. Local Whisper profiles show "Local Whisper" as the engine.

**Q: Can my employer/ISP see my transcriptions?**
A: When using Local Whisper, no. All traffic is localhost-only. Your network administrator cannot see transcription content. When using OpenAI API, transcriptions travel over the internet (encrypted via HTTPS).

---

**Last Updated:** 2025-11-19
**Applies to:** speech-to-clip with Local Whisper integration

For technical questions or privacy concerns: [GitHub Issues](https://github.com/Latentti/speech-to-clip/issues)
