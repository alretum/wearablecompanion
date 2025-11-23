# 🛡️ Guardian Angel Demo Mode - Deployment Guide

## Quick Setup for Huawei Watch 5

### Step 1: Configure Your AWS Endpoint

Edit `entry/src/main/ets/config/AppConfig.ets` and update line 16:

```typescript
// Replace with your actual AWS backend endpoint
static readonly DEMO_CALL_ENDPOINT = 'https://your-aws-endpoint.execute-api.region.amazonaws.com/prod/trigger-call';
```

### Step 2: Build and Deploy to Watch

1. **Open in DevEco Studio**
   - File → Open → Select `wearablecompanion` folder
   - Wait for project to sync

2. **Connect Your Huawei Watch 5**
   - Enable Developer Mode on watch
   - Connect via USB or WiFi debugging
   - Verify connection in DevEco Studio

3. **Build and Run**
   - Click the green "Run" button (or Shift+F10)
   - Select your Huawei Watch 5 as target
   - Wait for installation to complete

### Step 3: Grant Permissions

When the app launches for the first time:
- Allow sensor access (accelerometer, gyroscope)
- Allow location access (for GPS coordinates)
- Allow audio playback
- Allow background running

### Step 4: Test the Demo

1. **Start Monitoring**
   - Tap "Start Monitoring" button in the app
   - Watch should show "Monitoring..." status

2. **Trigger the Demo**
   - **Hold the watch on your wrist**
   - **Shake your wrist VIGOROUSLY** back and forth
   - Must generate >6.0 m/s² acceleration (rapid, forceful shaking)
   - Continue for about 1 second

3. **Expected Behavior**
   ```
   Immediate (T=0s):
   ✅ Red screen appears: "BREATHE. STEP TO THE BEAT."
   ✅ Watch vibrates continuously (500ms on, 200ms off pattern)
   ✅ Metronome audio plays in loop
   
   After 15 seconds (T=15s):
   ✅ Screen turns blue: "Calling Guardian..."
   ✅ HTTP POST sent to your AWS endpoint
   ✅ Success: Green screen "Guardian Notified"
   ✅ Or Error: Red screen "Call Failed"
   ```

4. **Stop the Demo**
   - Tap "Stop Demo" button on success/error screen
   - Or stop monitoring to auto-stop demo

---

## Troubleshooting

### Demo Won't Trigger

**Issue**: Shaking doesn't start the demo

**Solutions**:
- Shake MORE VIGOROUSLY - needs rapid, forceful motion
- Ensure monitoring is active (green status)
- Check if demo already running (only triggers once until stopped)
- Try rapid wrist flicks back and forth

**Test the threshold**: The algorithm looks for acceleration magnitude that deviates from gravity (9.8 m/s²) by more than 6.0 m/s². This means you need to hit approximately 15.8 m/s² or 3.8 m/s² total acceleration.

### No Audio

**Issue**: Metronome doesn't play

**Solutions**:
- Check `ras_metronome.mp3` exists in `entry/src/main/resources/base/media/`
- Verify audio permission granted
- Check watch volume isn't muted
- Look at logs for AudioPlayer errors

### No Vibration

**Issue**: Watch doesn't vibrate

**Solutions**:
- Check watch isn't in silent/DND mode
- Verify vibration permission granted
- Some watches have vibration disabled in settings

### Network Error

**Issue**: Shows "Call Failed - Network Error"

**Solutions**:
- Verify `DEMO_CALL_ENDPOINT` is correct in AppConfig.ets
- Ensure watch is connected to WiFi (Settings → WiFi)
- Test your AWS endpoint with curl:
  ```bash
  curl -X POST https://your-endpoint/trigger-call \
    -H "Content-Type: application/json" \
    -d '{"deviceId":"TEST","reason":"FOG_INCIDENT"}'
  ```
- Check AWS CloudWatch logs for backend errors

### App Crashes

**Issue**: App closes unexpectedly

**Solutions**:
- Check DevEco Studio logs (Logcat)
- Look for `hilog` messages with domain `0x0010` (DemoManager)
- Verify all permissions granted
- Try uninstalling and reinstalling the app

---

## Adjusting Sensitivity

If the shake trigger is too sensitive or not sensitive enough, edit `MotionAnalyzer.ets`:

```typescript
// Line ~231 in MotionAnalyzer.ets
public detectDemoTrigger(xData: number[], yData: number[], zData: number[]): boolean {
  const DEMO_SHAKE_THRESHOLD = 6.0; // ADJUST THIS VALUE
  
  // Lower = more sensitive (triggers easier)
  // Higher = less sensitive (needs harder shake)
  // Recommended range: 4.0 - 8.0
```

**Recommended values**:
- `4.0` - Easy to trigger (light shaking)
- `6.0` - Default (moderate shaking)
- `8.0` - Hard to trigger (violent shaking only)

After changing, rebuild and redeploy to watch.

---

## Viewing Logs

To see what's happening during the demo:

1. **Connect watch via USB**
2. **Open DevEco Studio**
3. **Open Logcat** (View → Tool Windows → Logcat)
4. **Filter logs**:
   - Set filter to show only your app
   - Search for "DemoManager" to see demo events
   - Search for "MotionAnalyzer" to see shake detection

**Key log messages**:
```
🚨 DEMO TRIGGER DETECTED: magnitude=16.2, deviation=6.4 > 6.0
⚡ PHASE 1: Starting immediate intervention
🎵 Metronome started
📳 Vibration started
⏰ Scheduling phone call trigger in 15000ms
📞 PHASE 2: Triggering phone call to guardian
Sending POST to https://your-endpoint...
✅ Phone call triggered successfully
```

---

## Expected AWS Backend Payload

Your AWS endpoint will receive:

```json
{
  "deviceId": "WATCH_DEMO",
  "reason": "FOG_INCIDENT",
  "timestamp": "2025-11-23T10:30:00.000Z",
  "location": "DEMO_MODE"
}
```

Expected response (success):
```json
{
  "success": true
}
```

Or any HTTP 200/201 status code will be treated as success.

---

## Quick Reference: Shake Technique

**Best technique to trigger the demo**:

1. **Wear the watch** (detection works better on wrist)
2. **Hold forearm steady**
3. **Rapid wrist rotations** - like shaking water off your hand
4. **Fast, forceful motion** - not gentle
5. **1-2 seconds duration** - continuous shaking
6. **Practice a few times** to get the feel

**Alternative techniques**:
- Quick back-and-forth hand movements (like waving rapidly)
- Rapid up-and-down hand flicks
- Vigorous hand shaking motion (like shaking hands very fast)

The key is **speed and force** - the algorithm needs to see sudden, large changes in acceleration.

---

## Demo Day Tips

1. **Before presenting**:
   - Fully charge the watch
   - Connect to venue WiFi
   - Test the shake trigger once
   - Know your threshold (how hard to shake)

2. **During demo**:
   - Wear the watch (not holding it)
   - Shake confidently and vigorously
   - Don't be shy - really shake it!
   - If first shake doesn't trigger, try harder

3. **Backup plan**:
   - If shake won't trigger, explain algorithm
   - Show code (MotionAnalyzer.detectDemoTrigger)
   - Explain the 6.0 m/s² threshold
   - Show UI mockups or screenshots

---

## Files Overview

**Core Demo Mode Files**:
```
services/DemoManager.ets       - Orchestrates demo sequence
services/AudioPlayer.ets        - Plays metronome audio
algorithms/MotionAnalyzer.ets   - Detects violent shake
services/MonitoringService.ets  - Integrates with sensor pipeline
pages/Index.ets                 - Shows UI overlays
config/AppConfig.ets            - Configure AWS endpoint
```

**Audio Resource**:
```
resources/base/media/ras_metronome.mp3
```

---

## Next Steps

1. ✅ Update `DEMO_CALL_ENDPOINT` in AppConfig.ets
2. ✅ Build and deploy to your Huawei Watch 5
3. ✅ Grant all permissions
4. ✅ Start monitoring
5. ✅ Practice shake gesture
6. ✅ Test full workflow
7. ✅ Show it off! 🛡️

---

**Your Guardian Angel is ready to protect!**

For detailed technical documentation, see `DEMO_MODE_GUIDE.md`.
