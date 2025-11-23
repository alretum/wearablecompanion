# Algorithm Implementation Guide

Quick reference for implementing the Parkinson's freeze prediction and tremor detection algorithms.

## Overview of Required Implementations

You need to implement the actual detection logic in two files:
1. `entry/src/main/ets/algorithms/PredictionAlgorithm.ets` - Freeze prediction
2. `entry/src/main/ets/algorithms/TremorDetector.ets` - Tremor detection

## 1. Activity and Motion Detection (`TremorDetector.ets`)

**Note**: This component detects activity status and motion characteristics. The data (status, magnitude, frequency) is reported as part of the 5-minute heart rate report, NOT as separate incident reports.

### Key Characteristics of Parkinson's Tremor

- **Frequency**: 4-6 Hz (most commonly ~5 Hz)
- **Type**: Resting tremor (occurs when muscles are relaxed)
- **Pattern**: Rhythmic, oscillatory
- **Amplitude**: Variable, but measurable with accelerometer

### Implementation Approach

#### Option A: Fast Fourier Transform (FFT)

```typescript
private analyzeTremorPattern(): boolean {
  const windowSize = 50; // 1 second at 50 Hz
  if (this.accelBuffer.length < windowSize) return false;

  const recentAccel = this.accelBuffer.slice(-windowSize);
  
  // Calculate magnitude
  const signal = recentAccel.map(a => 
    Math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
  );

  // Apply FFT (you'll need to import/implement FFT)
  const frequencies = performFFT(signal);
  
  // Find peak frequency
  const peakFreq = findPeakFrequency(frequencies);
  
  // Check if peak is in tremor range (4-6 Hz)
  return peakFreq >= 4 && peakFreq <= 6;
}
```

#### Option B: Autocorrelation (Simpler, No FFT Library Needed)

```typescript
private analyzeTremorPattern(): boolean {
  const windowSize = 50;
  if (this.accelBuffer.length < windowSize) return false;

  const recentAccel = this.accelBuffer.slice(-windowSize);
  const signal = recentAccel.map(a => 
    Math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
  );

  // Calculate autocorrelation
  const lag = this.findBestLag(signal, 8, 12); // 8-12 samples = 4-6 Hz at 50Hz
  
  if (lag === -1) return false;
  
  // Calculate frequency from lag
  const frequency = 50 / lag; // 50 Hz sampling rate
  
  return frequency >= 4 && frequency <= 6;
}

private findBestLag(signal: number[], minLag: number, maxLag: number): number {
  let bestLag = -1;
  let maxCorrelation = -Infinity;
  
  for (let lag = minLag; lag <= maxLag; lag++) {
    let correlation = 0;
    const n = signal.length - lag;
    
    for (let i = 0; i < n; i++) {
      correlation += signal[i] * signal[i + lag];
    }
    
    correlation /= n;
    
    if (correlation > maxCorrelation) {
      maxCorrelation = correlation;
      bestLag = lag;
    }
  }
  
  // Threshold for significant correlation
  return maxCorrelation > 0.5 ? bestLag : -1;
}
```

#### Option C: Peak Detection (Simplest)

```typescript
private analyzeTremorPattern(): boolean {
  const windowSize = 50; // 1 second
  if (this.accelBuffer.length < windowSize) return false;

  const recentAccel = this.accelBuffer.slice(-windowSize);
  const magnitudes = recentAccel.map(a => 
    Math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
  );

  // Count peaks
  const peaks = this.countPeaks(magnitudes);
  
  // 4-6 Hz means 4-6 peaks per second
  // In 1 second (50 samples), expect 4-6 peaks
  const hasCorrectFrequency = peaks >= 4 && peaks <= 6;
  
  // Check amplitude is significant
  const variance = this.calculateVariance(magnitudes);
  const hasSignificantAmplitude = variance > 0.3;
  
  return hasCorrectFrequency && hasSignificantAmplitude;
}
```

### Severity Calculation

```typescript
private calculateTremorSeverity(): number {
  if (!this.currentTremor) return 0;
  
  const magnitudes = this.currentTremor.accelerometerData.map(a =>
    Math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
  );
  
  // Calculate metrics
  const maxAmplitude = Math.max(...magnitudes);
  const avgAmplitude = magnitudes.reduce((a, b) => a + b) / magnitudes.length;
  const variance = this.calculateVariance(magnitudes);
  const duration = this.currentTremor.duration;
  
  // Weighted combination
  // Higher amplitude and longer duration = higher severity
  let severity = 0;
  
  // Amplitude contribution (0-5 points)
  severity += Math.min(avgAmplitude * 2, 5);
  
  // Duration contribution (0-3 points)
  severity += Math.min(duration / 1000, 3); // 3 points at 3+ seconds
  
  // Consistency contribution (0-2 points)
  severity += variance > 0.5 ? 2 : (variance > 0.2 ? 1 : 0);
  
  return Math.min(severity, 10);
}
```

## 2. Freeze Prediction (`PredictionAlgorithm.ets`)

### Known Indicators of Freezing of Gait

1. **Gait festination**: Rapid, short, shuffling steps
2. **Stride variability**: Inconsistent step patterns
3. **Tremor increase**: Elevated tremor before freeze
4. **Heart rate spike**: Stress/anxiety indicator
5. **Reduced acceleration**: Slower movement

### Implementation Approach

#### Step 1: Extract Features

```typescript
private extractFeatures(): {
  strideVariability: number;
  averageSpeed: number;
  tremorIntensity: number;
  heartRateChange: number;
} {
  // Stride variability from vertical (Y-axis) acceleration
  const verticalAccel = this.accelBuffer.map(a => a.y);
  const strideVariability = this.calculateVariance(verticalAccel);
  
  // Average movement speed from total acceleration magnitude
  const speeds = this.accelBuffer.map(a => 
    Math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
  );
  const averageSpeed = speeds.reduce((a, b) => a + b) / speeds.length;
  
  // Tremor intensity from high-frequency components
  const tremorIntensity = this.detectTremorPattern() ? 1.0 : 0.0;
  
  // Heart rate change
  const recentHR = this.heartRateHistory.slice(-5);
  const baselineHR = this.heartRateHistory.slice(-20, -5);
  const recentAvg = recentHR.reduce((s, hr) => s + hr.bpm, 0) / recentHR.length;
  const baselineAvg = baselineHR.reduce((s, hr) => s + hr.bpm, 0) / baselineHR.length;
  const heartRateChange = recentAvg - baselineAvg;
  
  return { strideVariability, averageSpeed, tremorIntensity, heartRateChange };
}
```

#### Step 2: Rule-Based Prediction

```typescript
private calculateFreezeProbability(indicators: {
  tremor: boolean;
  gaitDisturbance: boolean;
  stressSpike: boolean;
}): number {
  const features = this.extractFeatures();
  
  let probability = 0;
  
  // High stride variability (festination)
  if (features.strideVariability > 3.0) {
    probability += 0.3;
  }
  
  // Low movement speed (hesitation)
  if (features.averageSpeed < 0.5) {
    probability += 0.2;
  }
  
  // Tremor present
  if (indicators.tremor) {
    probability += 0.2;
  }
  
  // Gait disturbance
  if (indicators.gaitDisturbance) {
    probability += 0.2;
  }
  
  // Stress spike
  if (indicators.stressSpike) {
    probability += 0.1;
  }
  
  return Math.min(probability, 1.0);
}
```

#### Step 3: Machine Learning Model (Advanced)

If you have labeled training data:

```typescript
private calculateFreezeProbability(indicators: {
  tremor: boolean;
  gaitDisturbance: boolean;
  stressSpike: boolean;
}): number {
  // Extract feature vector
  const features = this.extractFeatureVector();
  
  // Load your trained model (e.g., using TensorFlow Lite)
  // const model = loadModel('freeze_prediction_model');
  
  // Make prediction
  // const prediction = model.predict(features);
  
  // For now, placeholder:
  // TODO: Implement ML model inference
  
  return this.ruleBasedPrediction(features);
}

private extractFeatureVector(): number[] {
  // Extract all relevant features as a numeric array
  const recent = this.accelBuffer.slice(-50);
  
  return [
    this.calculateMean(recent.map(a => a.x)),
    this.calculateMean(recent.map(a => a.y)),
    this.calculateMean(recent.map(a => a.z)),
    this.calculateVariance(recent.map(a => a.x)),
    this.calculateVariance(recent.map(a => a.y)),
    this.calculateVariance(recent.map(a => a.z)),
    this.heartRateHistory[this.heartRateHistory.length - 1]?.bpm || 0,
    // Add more features as needed
  ];
}
```

### Gait Disturbance Detection

```typescript
private detectGaitDisturbance(): boolean {
  if (this.accelBuffer.length < 50) return false;
  
  // Focus on vertical (Y) and forward (Z) acceleration
  const verticalAccel = this.accelBuffer.slice(-50).map(a => a.y);
  const forwardAccel = this.accelBuffer.slice(-50).map(a => a.z);
  
  // Calculate step frequency from peaks in vertical acceleration
  const peaks = this.countPeaks(verticalAccel);
  const stepFrequency = peaks; // peaks per second
  
  // Normal walking: 1.5-2 steps per second
  // Festination: > 3 steps per second
  // Freezing precursor: < 1 step per second or very irregular
  
  const isFestination = stepFrequency > 3;
  const isHesitation = stepFrequency < 1;
  
  // Check stride variability
  const strideVariability = this.calculateVariance(verticalAccel);
  const isIrregular = strideVariability > 2.5;
  
  return isFestination || isHesitation || isIrregular;
}
```

## 3. Validation and Testing

### Test with Synthetic Data

```typescript
// Create test data for tremor
function generateTremorData(frequency: number, amplitude: number, duration: number): AccelerometerData[] {
  const sampleRate = 50; // Hz
  const samples = duration * sampleRate / 1000; // milliseconds to samples
  const data: AccelerometerData[] = [];
  
  for (let i = 0; i < samples; i++) {
    const t = i / sampleRate;
    const tremorValue = amplitude * Math.sin(2 * Math.PI * frequency * t);
    
    data.push({
      x: tremorValue + (Math.random() - 0.5) * 0.1, // Add noise
      y: 9.8 + (Math.random() - 0.5) * 0.1, // Gravity + noise
      z: tremorValue * 0.5 + (Math.random() - 0.5) * 0.1,
      timestamp: Date.now() + i * 20 // 20ms intervals
    });
  }
  
  return data;
}

// Test tremor detector
const testTremorData = generateTremorData(5, 1.5, 2000); // 5 Hz, amplitude 1.5, 2 seconds
testTremorData.forEach(data => {
  const result = tremorDetector.detectTremor(data, gyroData);
  // Check results
});
```

### Metrics to Track

1. **True Positive Rate**: Correctly detected freezes
2. **False Positive Rate**: False alarms
3. **Prediction Lead Time**: How early you predict
4. **Sensitivity**: Can you detect all tremors?
5. **Specificity**: Do you avoid false tremor detections?

## 4. Optimization Tips

### Performance
- Keep buffer sizes reasonable (100 samples = 2 seconds)
- Use efficient algorithms (avoid nested loops)
- Consider downsampling if needed

### Accuracy
- Tune thresholds based on real data
- Consider person-specific calibration
- Use multiple indicators (sensor fusion)

### Battery Life
- Reduce sampling rate if possible
- Batch processing instead of per-sample
- Minimize network requests

## 5. Resources

### Research Papers
- "Freezing of gait in Parkinson's disease" - Clinical indicators
- "Wearable sensors for gait analysis" - Sensor data interpretation
- "Machine learning for Parkinson's detection" - ML approaches

### Libraries to Consider
- **FFT**: Use WebAssembly FFT library if available
- **Signal Processing**: Consider porting scipy functions
- **ML**: TensorFlow Lite for on-device inference

## 6. Quick Start Checklist

- [ ] Choose tremor detection method (FFT, autocorrelation, or peaks)
- [ ] Implement `analyzeTremorPattern()` in `TremorDetector.ets`
- [ ] Implement `calculateTremorSeverity()` in `TremorDetector.ets`
- [ ] Implement `detectGaitDisturbance()` in `PredictionAlgorithm.ets`
- [ ] Implement `calculateFreezeProbability()` in `PredictionAlgorithm.ets`
- [ ] Test with synthetic data
- [ ] Calibrate thresholds with real data
- [ ] Validate on clinical datasets
- [ ] Optimize for battery and performance

## 7. Next Steps After Implementation

1. **Collect training data** from Parkinson's patients
2. **Train ML model** if using machine learning approach
3. **Clinical validation** with medical professionals
4. **IRB approval** for human subjects research
5. **FDA/regulatory approval** for medical device classification
