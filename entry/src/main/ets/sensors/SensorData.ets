/**
 * SensorData types and interfaces for Parkinson's freeze detection
 */

// Sensor reading interfaces
export interface AccelerometerData {
  x: number;
  y: number;
  z: number;
  timestamp: number;
}

export interface GyroscopeData {
  x: number;
  y: number;
  z: number;
  timestamp: number;
}

export interface HeartRateData {
  bpm: number;
  timestamp: number;
  variability?: number; // For detecting pulse spikes
}

// Activity status for tremor/motion classification
export enum ActivityStatus {
  SEDENTARY = 'sedentary',    // Minimal movement, at rest
  ACTIVE = 'active',          // Significant movement detected
  UNKNOWN = 'unknown',        // Cannot determine status
  NOT_WORN = 'not_worn'       // Device not being worn (heart rate invalid)
}

// Tremor/motion data - reports activity status and motion metrics
export interface TremorEvent {
  status: ActivityStatus;  // Activity classification
  magnitude: number;       // Motion magnitude (m/s²)
  frequency: number;       // Dominant frequency (Hz), 0 if not detected
  timestamp: number;       // Unix timestamp in milliseconds
}

// GPS coordinate data
export interface GPSCoordinates {
  latitude: number; // Decimal degrees (-90 to 90)
  longitude: number; // Decimal degrees (-180 to 180)
  altitude?: number; // Meters above sea level
  accuracy?: number; // Horizontal accuracy in meters
  timestamp: number; // Unix timestamp in milliseconds
}

// Freeze prediction result
export interface FreezeIndicators {
  tremor: boolean;
  gaitDisturbance: boolean;
  stressSpike: boolean;
}

export interface FreezePrediction {
  probability: number; // 0-1 scale
  timeToFreeze?: number; // milliseconds until predicted freeze
  timestamp: number;
  confidence: number; // 0-1 scale
  indicators: FreezeIndicators;
  gpsCoordinates?: GPSCoordinates; // GPS location when freeze detected (only for freezes)
}

// Monitoring status
export enum MonitoringStatus {
  STOPPED = 'stopped',
  MONITORING = 'monitoring',
  ALERT = 'alert',
  ERROR = 'error'
}

// Application state for UI
export class AppState {
  status: MonitoringStatus = MonitoringStatus.STOPPED;
  currentAccel: AccelerometerData | null = null;
  currentGyro: GyroscopeData | null = null;
  currentHeartRate: HeartRateData | null = null;
  
  // Last saved values (what's actually persisted to file)
  lastSavedAccel: AccelerometerData | null = null;
  lastSavedGyro: GyroscopeData | null = null;
  lastSavedHeartRate: HeartRateData | null = null;
  
  latestPrediction: FreezePrediction | null = null;
  latestTremor: TremorEvent | null = null;
  errorMessage: string = '';
  
  // Statistics
  totalTremorsDetected: number = 0;
  totalFreezesDetected: number = 0;
  monitoringStartTime: number = 0;
}
