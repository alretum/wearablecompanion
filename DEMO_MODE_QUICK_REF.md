# 🛡️ Guardian Angel Demo Mode - Quick Reference

## Quick Start (5 Minutes)

### 1. Configure Backend Endpoint
```typescript
// entry/src/main/ets/config/AppConfig.ets
static readonly DEMO_CALL_ENDPOINT = 'https://your-backend-url.com/trigger-call';
```

### 2. Deploy Backend (Node.js Example)
```javascript
const twilio = require('twilio');
const client = twilio(accountSid, authToken);

app.post('/trigger-call', async (req, res) => {
  const call = await client.calls.create({
    to: '+1234567890',     // Guardian phone
    from: '+0987654321',   // Your Twilio number
    twiml: '<Response><Say>Emergency: Freezing detected</Say></Response>'
  });
  res.json({ success: true, callSid: call.sid });
});
```

### 3. Test the Demo
1. Start monitoring in app
2. **Shake wrist vigorously** for ~1 second
3. Red screen appears → Metronome plays → Vibration starts
4. Wait 15 seconds
5. Phone call triggered automatically

---

## Demo Flow Summary

```
┌─────────────────────────────────────────────────────────────┐
│  TRIGGER: Violent Wrist Shake (>6.0 m/s² deviation)        │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ↓
┌─────────────────────────────────────────────────────────────┐
│  PHASE 1 (T=0s): IMMEDIATE INTERVENTION                     │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│  🔴 Red Screen: "BREATHE. STEP TO THE BEAT."                │
│  📳 Continuous Vibration (500ms on, 200ms off)              │
│  🎵 Metronome Audio Loop                                    │
└──────────────────────┬──────────────────────────────────────┘
                       │ 15 seconds countdown
                       ↓
┌─────────────────────────────────────────────────────────────┐
│  PHASE 2 (T=15s): TRIGGER GUARDIAN CALL                     │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│  🔵 Blue Screen: "Calling Guardian..."                      │
│  📞 HTTP POST → Backend/Twilio Endpoint                     │
│  📱 Phone Call Initiated to Guardian                        │
└──────────────────────┬──────────────────────────────────────┘
                       │
                ┌──────┴──────┐
                ↓             ↓
        ┌────────────┐  ┌────────────┐
        │  SUCCESS   │  │   ERROR    │
        │  🟢 Green  │  │  🔴 Red    │
        │  "Guardian │  │  "Call     │
        │  Notified" │  │  Failed"   │
        └────────────┘  └────────────┘
```

---

## Technical Details

### Detection Algorithm
- **File**: `algorithms/MotionAnalyzer.ets`
- **Method**: `detectDemoTrigger(xData, yData, zData)`
- **Logic**: Calculate Euclidean magnitude, check if |mag - 9.8| > 6.0

### Orchestration
- **File**: `services/DemoManager.ets`
- **Pattern**: Singleton with state machine
- **States**: INACTIVE → INTERVENTION → CALLING_GUARDIAN → SUCCESS/ERROR

### Audio Playback
- **File**: `services/AudioPlayer.ets`
- **Resource**: `resources/base/media/ras_metronome.mp3`
- **Workaround**: Copies to cache, loads via file:// URI

### UI Integration
- **File**: `pages/Index.ets`
- **Pattern**: Stack with overlay
- **Updates**: Real-time state sync via callbacks

---

## Configuration Options

| Setting | Location | Default | Purpose |
|---------|----------|---------|---------|
| `DEMO_CALL_ENDPOINT` | `AppConfig.ets` | `'https://your-backend-url.com/trigger-call'` | Backend URL for Twilio |
| `DEMO_DELAY_MS` | `DemoManager.ets` | `15000` | Seconds until call (15s) |
| Shake threshold | `MotionAnalyzer.ets` | `6.0` | m/s² deviation to trigger |
| Vibration pattern | `DemoManager.ets` | `500/200ms` | ON/OFF duration |

---

## Backend API Contract

### Request (from Watch)
```http
POST /trigger-call
Content-Type: application/json

{
  "deviceId": "WATCH_DEMO",
  "reason": "FOG_INCIDENT",
  "timestamp": "2025-11-23T10:30:00.000Z",
  "location": "DEMO_MODE"
}
```

### Response (Expected)
```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "success": true,
  "callSid": "CAxxxxxxxxxxxxxxxx" // Optional
}
```

---

## Demo Scenarios

### ✅ Happy Path
1. User shakes watch vigorously
2. Red screen appears with metronome
3. 15 seconds pass
4. Backend returns 200 OK
5. Green "Guardian Notified" screen
6. User clicks "Stop Demo"

### ❌ Network Error
1. User shakes watch
2. Red screen appears
3. 15 seconds pass
4. Network request fails (timeout/error)
5. Red "Call Failed" screen
6. User clicks "Stop Demo"

### 🛑 Manual Stop
1. User shakes watch
2. Demo starts
3. User stops monitoring
4. Demo automatically stops
5. Audio/vibration cease

---

## Testing Checklist

- [ ] Endpoint configured in `AppConfig.ets`
- [ ] Backend server running and accessible
- [ ] Watch connected to network (WiFi/cellular)
- [ ] Monitoring started in app
- [ ] Shake gesture practiced (needs to be vigorous)
- [ ] Audio file `ras_metronome.mp3` exists
- [ ] Vibration permission granted
- [ ] Test with httpbin.org first (mock endpoint)
- [ ] Verify backend receives request
- [ ] Confirm Twilio call is made
- [ ] Test stop button functionality

---

## Troubleshooting Quick Fixes

| Problem | Solution |
|---------|----------|
| Demo won't trigger | Shake harder, ensure monitoring active |
| No audio | Check `ras_metronome.mp3` in resources |
| No vibration | Check permissions, watch not in silent mode |
| Call fails | Verify endpoint URL, test with curl |
| Backend error | Check logs, verify Twilio credentials |

---

## Performance Notes

- **Latency**: <100ms from shake to screen update
- **Buffer**: 50 samples analyzed (1 second at 50Hz)
- **Network**: 10s timeout for HTTP request
- **Audio**: Cached on init, instant playback
- **Battery**: Vibration most intensive, demo is short-lived

---

## Files Modified

| File | Changes |
|------|---------|
| `DemoManager.ets` | ✅ New - Demo orchestration |
| `AudioPlayer.ets` | ✅ New - Audio playback |
| `MotionAnalyzer.ets` | ✅ Added `detectDemoTrigger()` |
| `MonitoringService.ets` | ✅ Integrated demo checks |
| `TremorDetector.ets` | ✅ Exposed buffer/analyzer |
| `Index.ets` | ✅ Added demo overlay UI |
| `AppConfig.ets` | ✅ Added `DEMO_CALL_ENDPOINT` |

---

## Hackathon Pitch Points

🎯 **Problem**: Parkinson's patients freeze and can't call for help

💡 **Solution**: Watch detects freeze, automatically calls guardian

⚡ **Innovation**: Multi-modal intervention + automatic escalation

🛡️ **Impact**: Peace of mind for patients and families

📱 **Tech Stack**: HarmonyOS + Sensors + Cloud + Twilio

---

## Next Steps After Demo

1. **Enhance Detection**: Train ML model on real FoG data
2. **GPS Integration**: Send location with call
3. **Multi-Guardian**: Call list with escalation
4. **Voice Recording**: Patient can speak to guardian
5. **Historical Context**: Include recent incident data
6. **SMS Fallback**: Backup communication channel

---

**For detailed documentation, see `DEMO_MODE_GUIDE.md`**

**Built with ❤️ for Parkinson's Patients** 🛡️
