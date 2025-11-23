# 🛡️ Guardian Angel Demo Mode - Implementation Guide

## Overview

The Guardian Angel Demo Mode simulates a Freezing of Gait (FoG) incident detection and automatically triggers a phone call to a guardian through Twilio integration. This demo showcases the complete intervention pipeline from detection to emergency response.

---

## 🎯 Demo Flow

### Trigger
- **Detection Method**: Violent wrist shake (Energy > 6.0 m/s²)
- **Implementation**: `MotionAnalyzer.detectDemoTrigger()`
- **Threshold**: |Magnitude - 9.8| > 6.0 m/s² (approximately 0.6G of shaking force)

### Phase 1: Immediate Intervention (T=0s)

**Visual Feedback**:
- Full-screen red flashing overlay
- Large text: "BREATHE. STEP TO THE BEAT."
- Guardian icon (🛡️)
- Status indicators

**Haptic Feedback**:
- Continuous vibration pattern (500ms ON, 200ms OFF)
- Uses `vibrator` service with 'alarm' usage level
- Loops until demo stops

**Audio Feedback**:
- Plays `ras_metronome.mp3` in continuous loop
- Loaded from cache directory (workaround for HarmonyOS limitation)
- Uses AVPlayer with loop mode enabled

### Phase 2: Guardian Call (T=15s)

**Network Request**:
- HTTP POST to backend/Twilio endpoint
- Endpoint: Configured in `AppConfig.DEMO_CALL_ENDPOINT`
- Payload includes device ID, reason, timestamp, location

**UI Update**:
- Changes to blue screen
- Shows "Calling Guardian..."
- Loading spinner animation

**Success/Error Handling**:
- **Success** (HTTP 200/201): Green screen "Guardian Notified"
- **Error**: Red screen "Call Failed - Network Error"

---

## 📂 Architecture

### Components

1. **DemoManager** (`services/DemoManager.ets`)
   - Singleton service managing demo lifecycle
   - Orchestrates audio, vibration, and network calls
   - Maintains demo state machine
   - Handles 15-second timer

2. **AudioPlayer** (`services/AudioPlayer.ets`)
   - Manages metronome playback
   - Implements cache workaround for HarmonyOS resource loading
   - Uses AVPlayer with loop mode

3. **MotionAnalyzer** (`algorithms/MotionAnalyzer.ets`)
   - `detectDemoTrigger()` method for shake detection
   - Analyzes accelerometer buffer (50 samples)
   - Calculates Euclidean magnitude and deviation from gravity

4. **MonitoringService** (`services/MonitoringService.ets`)
   - Integrates DemoManager into sensor pipeline
   - Calls `checkDemoTrigger()` on every sensor reading
   - Exposes DemoManager to UI

5. **Index UI** (`pages/Index.ets`)
   - Demo intervention overlay with Stack layout
   - Real-time demo state display
   - Manual stop button

---

## ⚙️ Configuration

### Backend Endpoint

Edit `entry/src/main/ets/config/AppConfig.ets`:

```typescript
// 🛡️ DEMO MODE: Guardian Angel - Twilio Phone Call Trigger
// Replace with your actual backend endpoint that triggers the Twilio call
static readonly DEMO_CALL_ENDPOINT = 'https://your-backend-url.com/trigger-call';
```

### Request Payload

The demo sends the following JSON to your backend:

```json
{
  "deviceId": "WATCH_DEMO",
  "reason": "FOG_INCIDENT",
  "timestamp": "2025-11-23T10:30:00.000Z",
  "location": "DEMO_MODE"
}
```

### Expected Backend Response

- **Success**: HTTP 200 or 201
- **Body** (optional): Any JSON response

---

## 🎬 How to Trigger the Demo

### During Monitoring

1. Start monitoring in the app
2. Hold the watch in your hand
3. **Shake your wrist vigorously** back and forth
4. Maintain high-intensity shaking for ~1 second
5. The demo will trigger when magnitude exceeds threshold

### Threshold Details

- **Gravity baseline**: 9.8 m/s²
- **Threshold**: 6.0 m/s² deviation
- **Total magnitude required**: ~15.8 m/s² or ~3.8 m/s²
- **Practical gesture**: Rapid wrist flicks or violent shaking

### What Happens

1. ✅ Red screen appears immediately
2. 📳 Watch vibrates continuously
3. 🎵 Metronome plays (beat sound)
4. ⏰ 15-second countdown starts
5. 📞 Backend endpoint called at T=15s
6. ✅ Success/error screen shows result

---

## 🎵 Audio Resource

### File Location
```
entry/src/main/resources/base/media/ras_metronome.mp3
```

### Cache Workaround

HarmonyOS AVPlayer **cannot** load resources directly from `base/media/`. The AudioPlayer implements a workaround:

1. **On Init**: Copies `ras_metronome.mp3` from ResourceManager to `cacheDir`
2. **Cached Path**: `{context.cacheDir}/metronome_cache.mp3`
3. **Loading**: Uses `file://` URI to load from cache
4. **Cleanup**: Deletes cache file on destroy

### Code Reference

```typescript
// AudioPlayer.ets
private async copyResourceToCache(): Promise<void> {
  const resMgr = this.context.resourceManager;
  const fileData = await resMgr.getRawFileContent('ras_metronome.mp3');
  // Write to cache...
}
```

---

## 🔧 Backend Implementation (Example)

### Node.js + Twilio

```javascript
// Express endpoint
app.post('/trigger-call', async (req, res) => {
  const { deviceId, reason, timestamp } = req.body;
  
  try {
    const call = await twilioClient.calls.create({
      to: '+1234567890', // Guardian's phone number
      from: '+0987654321', // Your Twilio number
      twiml: `<Response>
        <Say>Emergency alert from Parkinson's monitor. 
             A freezing of gait incident was detected. 
             Please check on the patient immediately.</Say>
      </Response>`
    });
    
    console.log(`Call triggered: ${call.sid}`);
    res.status(200).json({ success: true, callSid: call.sid });
    
  } catch (error) {
    console.error('Twilio error:', error);
    res.status(500).json({ error: 'Failed to trigger call' });
  }
});
```

### Python + Twilio

```python
from twilio.rest import Client
from flask import Flask, request, jsonify

app = Flask(__name__)
client = Client(account_sid, auth_token)

@app.route('/trigger-call', methods=['POST'])
def trigger_call():
    data = request.json
    
    try:
        call = client.calls.create(
            to='+1234567890',  # Guardian
            from_='+0987654321',  # Twilio number
            twiml='<Response><Say>Emergency alert from Parkinsons monitor...</Say></Response>'
        )
        
        return jsonify({'success': True, 'callSid': call.sid}), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500
```

---

## 🧪 Testing Without Backend

For testing the UI and audio/vibration without a backend:

1. Set `DEMO_CALL_ENDPOINT` to a mock server:
   ```typescript
   static readonly DEMO_CALL_ENDPOINT = 'https://httpbin.org/post';
   ```

2. Or use a local test server:
   ```bash
   # Node.js test server
   const express = require('express');
   const app = express();
   app.post('/trigger-call', (req, res) => {
     res.json({ success: true });
   });
   app.listen(3000);
   ```

3. Update endpoint to your local IP:
   ```typescript
   static readonly DEMO_CALL_ENDPOINT = 'http://192.168.1.100:3000/trigger-call';
   ```

---

## 🎮 Demo Control

### Manual Stop

Users can manually stop the demo at any time:
- **Button appears** on success/error screens
- **Stops all**: Audio, vibration, timers
- **Resets state**: Ready for next demo run

### Code
```typescript
this.monitoringService.getDemoManager().stopDemo();
```

### Auto-Stop Scenarios

The demo automatically stops when:
1. ✅ Phone call successfully triggered (shows stop button)
2. ❌ Network error occurs (shows stop button)
3. ⏹️ User stops monitoring
4. 💀 App is destroyed/closed

---

## 📊 Demo State Machine

```
INACTIVE ──────────────────────────────────┐
   │                                        │
   │ (Violent shake detected)               │
   ↓                                        │
INTERVENTION ──────────────────────────────┤
   │ T=0s: Visual/Audio/Haptic starts       │
   │ Timer: 15 seconds                      │
   ↓                                        │
CALLING_GUARDIAN ─────────────────────────┤
   │ HTTP POST to backend                   │
   ├── Success → CALL_TRIGGERED ───────────┤
   └── Error   → ERROR ────────────────────┘
```

### State Enum

```typescript
export enum DemoState {
  INACTIVE = 'INACTIVE',
  INTERVENTION = 'INTERVENTION',
  CALLING_GUARDIAN = 'CALLING_GUARDIAN',
  CALL_TRIGGERED = 'CALL_TRIGGERED',
  ERROR = 'ERROR'
}
```

---

## 🐛 Troubleshooting

### Audio Not Playing

**Issue**: Metronome doesn't play
**Solutions**:
1. Check `ras_metronome.mp3` exists in `resources/base/media/`
2. Verify cache directory is writable
3. Check logs for ResourceManager errors
4. Ensure AVPlayer permissions granted

### Demo Not Triggering

**Issue**: Shaking doesn't start demo
**Solutions**:
1. Shake **more vigorously** (need >6.0 m/s² deviation)
2. Ensure monitoring is active
3. Check if demo already active (only triggers once)
4. Verify accelerometer is providing data

### Network Error

**Issue**: "Call Failed" error shown
**Solutions**:
1. Verify `DEMO_CALL_ENDPOINT` is correct
2. Check watch has internet connection (WiFi/cellular)
3. Test endpoint with curl/Postman
4. Check backend logs for errors
5. Verify CORS settings on backend

### Vibration Not Working

**Issue**: No haptic feedback
**Solutions**:
1. Check vibration permission granted
2. Verify watch supports vibration
3. Check watch not in silent/DND mode
4. Review vibrator service logs

---

## 📝 Key Files

| File | Purpose |
|------|---------|
| `services/DemoManager.ets` | Main demo orchestration |
| `services/AudioPlayer.ets` | Metronome playback |
| `algorithms/MotionAnalyzer.ets` | Shake detection algorithm |
| `services/MonitoringService.ets` | Integration with sensor pipeline |
| `pages/Index.ets` | UI overlays and visual feedback |
| `config/AppConfig.ets` | Configuration (endpoint URL) |
| `resources/base/media/ras_metronome.mp3` | Metronome audio file |

---

## 🚀 Hackathon Demo Script

### Setup (Before Demo)

1. ✅ Configure `DEMO_CALL_ENDPOINT` with your backend URL
2. ✅ Test backend endpoint with curl
3. ✅ Ensure watch connected to WiFi
4. ✅ Start monitoring in app
5. ✅ Practice trigger gesture (violent shake)

### Live Demo (Show to Judges)

1. **Intro**: "This watch detects Parkinson's freezing incidents"
2. **Trigger**: Shake wrist vigorously
3. **Phase 1**: Point out red screen, mention metronome/vibration
4. **Phase 2**: "After 15 seconds, it automatically calls the guardian"
5. **Success**: Show "Guardian Notified" confirmation
6. **Explain**: "This uses Twilio to make a real phone call"

### Talking Points

- ⚡ **Real-time detection** from wrist motion
- 🎵 **Multi-modal intervention** (visual, haptic, audio)
- 📞 **Automatic escalation** if patient doesn't recover
- 🛡️ **Guardian angel** concept - watching over the patient
- 🏥 **Medical-grade response** - immediate help
- 📱 **Integrated pipeline** - watch to cloud to phone call

---

## 💡 Advanced Features (Future Enhancements)

### Potential Additions

1. **GPS Location in Call**
   - Include patient location in Twilio message
   - "Patient is at [address]"

2. **SMS Fallback**
   - Send SMS if call fails
   - Include vital signs summary

3. **Multiple Guardians**
   - Call list with priority order
   - Escalate if first doesn't answer

4. **Voice Recording**
   - Record patient's voice saying help
   - Play in call to guardian

5. **Two-Way Communication**
   - Guardian can respond via keypress
   - Update watch with ETA

6. **Historical Context**
   - "3rd incident today"
   - "Patient took medication 2 hours ago"

---

## 📞 Support

For issues or questions during implementation:
- Check logs: `hilog` with domain `0x0010` (DemoManager)
- Review state transitions in `DemoManager`
- Test shake detection with lower threshold temporarily
- Use httpbin.org for network testing

---

**Built for HarmonyOS Hackathon 2025**
**Guardian Angel - Because Everyone Deserves Protection** 🛡️
