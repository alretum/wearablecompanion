# Debug Guide: Freeze Detection Not Working

## Step 1: Rebuild and Redeploy the App

**CRITICAL:** The changes to `FreezeDetector.ets` won't take effect until you rebuild and redeploy!

```bash
# Clean build
hvigorw clean

# Rebuild
hvigorw assembleHap

# Install to device
hdc install -r entry/build/default/outputs/default/entry-default-signed.hap
```

## Step 2: Connect Device and Access Logs

### Check Device Connection
```bash
hdc list targets
```

If empty, reconnect your device:
- Ensure USB debugging is enabled
- Reconnect USB cable
- Check device shows up with `hdc list targets`

### Real-Time Log Monitoring

**Option 1: Filter by Tags (Recommended)**
```bash
# Monitor FreezeDetector and GuardianService
hdc shell hilog -x | grep -E "FreezeDetector|GuardianService"
```

**Option 2: Filter by Domain**
```bash
# Monitor domain 0x0020 (where FreezeDetector logs)
hdc shell hilog -x -D 0x0020
```

**Option 3: All App Logs**
```bash
# See everything from the app
hdc shell hilog -x | grep "WearableCompanion"
```

**Option 4: Unfiltered (Verbose)**
```bash
# See all system logs
hdc shell hilog -x
```

### Save Logs to File
```bash
# Capture logs to file for analysis
hdc shell hilog -x > freeze_debug.log

# Then search in the file
grep "FreezeDetector" freeze_debug.log
grep "GuardianService" freeze_debug.log
grep "FOG" freeze_debug.log
```

## Step 3: Verify GuardianService is Running

### What to Look For in Logs

**1. Initialization (when app starts):**
```
GuardianService: GuardianService initialized
FreezeDetector: FreezeDetector initialized - Freeze Index algorithm
GuardianService: ✓ GuardianService initialized
```

**2. Monitoring Started (when you press Start):**
```
MonitoringService: Starting monitoring...
GuardianService: ✓ FoG monitoring started
```

**3. Buffer Filling (first second):**
```
FreezeDetector: Buffer filling: 10/50
FreezeDetector: Buffer filling: 20/50
FreezeDetector: Buffer filling: 30/50
FreezeDetector: Buffer filling: 40/50
FreezeDetector: Buffer filling: 50/50
```

**4. Detection Running (after buffer fills):**
```
FreezeDetector: Magnitude Stats: avg=9.85, min=9.20, max=10.50
FreezeDetector: [FOG] Normal: Ratio=0.85 < 1.5 (pFreeze=0.450, pLoco=0.530)
```

## Step 4: Diagnose the Issue

### Issue 1: NO LOGS AT ALL

**Symptoms:**
- No "FreezeDetector" or "GuardianService" in logs
- Grep returns nothing

**Possible Causes:**
- ❌ **App not rebuilt** - Changes not deployed
- ❌ **App not running** - Check if app is open on device
- ❌ **Wrong log level** - Though we changed to `info` level
- ❌ **GuardianService not starting** - Service crash or initialization failure

**Fix:**
1. Rebuild app completely (`hvigorw clean && hvigorw assembleHap`)
2. Reinstall app (`hdc install -r ...`)
3. Open app on device
4. Press "Start Monitoring"
5. Check logs again

### Issue 2: INITIALIZATION LOGS BUT NO BUFFER FILLING

**Symptoms:**
- See "FreezeDetector initialized"
- See "GuardianService initialized"  
- But NO "Buffer filling" messages

**Possible Causes:**
- ❌ **Accelerometer not subscribing** - GuardianService.startMonitoring() failing
- ❌ **Sensor permission denied** - Check permissions
- ❌ **Sensor not available** - Device doesn't have accelerometer (unlikely)

**Fix:**
1. Check for error logs mentioning "accelerometer" or "sensor"
2. Verify app permissions in device settings
3. Look for crash logs

### Issue 3: BUFFER FILLS BUT NO DETECTION LOGS

**Symptoms:**
- See "Buffer filling: 50/50"
- But NO detection logs after that

**Possible Causes:**
- ❌ **Algorithm crash** - Error in detection logic
- ❌ **Silent failure** - Exception being caught somewhere

**Fix:**
1. Look for error/exception logs
2. Check if app crashes after buffer fills
3. Add try-catch logging

### Issue 4: DETECTION LOGS BUT ALWAYS REJECTED

**Symptoms:**
- See detection logs
- But always "Motion Gate" or "Walk Gate" rejection
- Never triggers freeze

**Possible Causes:**
- ✅ Algorithm is working!
- ❌ **Wrong physical pattern** - Not performing correct test motion
- ❌ **Thresholds still too strict** - Need further adjustment

**Fix:**
See "Testing Pattern" below

## Step 5: Proper Testing Pattern

### The Freeze Pattern

The algorithm needs **BOTH** conditions:
1. **Low locomotor power** - Minimal slow arm swing (< 1.5 Hz)
2. **High freeze band power** - Rapid tremor-like shaking (1.5-8 Hz)

### How to Perform

**❌ WRONG - Will NOT Trigger:**
- Standing completely still (rejected by Motion Gate)
- Normal walking (rejected by Walk Gate)
- Large slow arm swings (high locomotor, low freeze index)

**✅ CORRECT - Should Trigger:**

1. **Starting Position:**
   - Wear watch on wrist
   - Hold arm in walking position (slightly bent)

2. **The Motion:**
   - Keep your arm mostly still (no large swings)
   - BUT shake your WRIST rapidly in small movements
   - Think: tremor or rapid tapping motion
   - Frequency: 2-5 shakes per second
   - Amplitude: Small, tight movements

3. **Duration:**
   - Maintain for at least 2 seconds
   - First second fills buffer
   - Second second triggers detection

### Expected Log Sequence

```
[Second 0-1: Buffer Filling]
FreezeDetector: Buffer filling: 10/50
FreezeDetector: Buffer filling: 20/50
FreezeDetector: Buffer filling: 30/50
FreezeDetector: Buffer filling: 40/50
FreezeDetector: Buffer filling: 50/50

[Second 1-2: Detection Active]
FreezeDetector: Magnitude Stats: avg=10.20, min=9.50, max=11.80
FreezeDetector: [FOG] Normal: Ratio=1.20 < 1.5 (pFreeze=0.680, pLoco=0.567)

[With correct pattern - freeze should trigger]
FreezeDetector: [FOG] ✅ FREEZE DETECTED! Ratio=2.30 (pFreeze=0.920, pLoco=0.400)
GuardianService: 🚨 [FOG_STARTED] Initiating intervention...
GuardianService: 🔊 Playing metronome audio (looping)
```

## Step 6: If Still Not Working

### Further Lower Thresholds

Edit `entry/src/main/ets/algorithms/FreezeDetector.ets`:

```typescript
// Even more sensitive
private readonly MOTION_GATE = 0.05;  // Was 0.1
private readonly WALK_GATE = 5.0;     // Was 2.0
private readonly FREEZE_RATIO = 1.2;  // Was 1.5
```

Then rebuild and redeploy.

### Check Values You're Actually Getting

Look at the logs and note:
- What's your pFreeze value?
- What's your pLoco value?
- What's your ratio?

If ratio is close to 1.5 (like 1.3-1.4), just lower FREEZE_RATIO.

### Enable Even More Verbose Logging

If you need to see EVERY sample, you can modify the detector to log every 5 samples instead of filtering.

## Quick Reference Commands

```bash
# 1. Rebuild app
hvigorw clean && hvigorw assembleHap

# 2. Reinstall
hdc install -r entry/build/default/outputs/default/entry-default-signed.hap

# 3. Monitor logs
hdc shell hilog -x | grep -E "FreezeDetector|GuardianService"

# 4. Or save to file
hdc shell hilog -x > logs.txt
# Then search: grep "FreezeDetector" logs.txt

# 5. Clear old logs
hdc shell hilog -r
```

## Common Mistakes

1. ❌ **Forgot to rebuild** - Changes won't apply without rebuild
2. ❌ **Old HAP cached** - Use `-r` flag to force reinstall
3. ❌ **Wrong motion** - Standing still or normal walking won't trigger
4. ❌ **Too short duration** - Need to maintain pattern for 2+ seconds
5. ❌ **Watching wrong logs** - Make sure grep pattern is correct

## Success Indicators

✅ You should see:
1. Initialization logs when app starts
2. "Monitoring started" when you press Start
3. Buffer filling logs in first second
4. Magnitude statistics every second
5. Detection attempts with actual pLoco/pFreeze values

If you see all of these, the system is working - you just need to find the right physical pattern or adjust thresholds based on the values you're seeing.
