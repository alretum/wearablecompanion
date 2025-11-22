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

// Tremor detection result
export interface TremorEvent {
  severity: number; // 0-10 scale
  duration: number; // milliseconds
  timestamp: number;
  accelerometerData: AccelerometerData[];
  gyroscopeData: GyroscopeData[];
}

// Freeze prediction result
export interface FreezePrediction {
  probability: number; // 0-1 scale
  timeToFreeze?: number; // milliseconds until predicted freeze
  timestamp: number;
  confidence: number; // 0-1 scale
  indicators: {
    tremor: boolean;
    gaitDisturbance: boolean;
    stressSpike: boolean;
  };
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
  latestPrediction: FreezePrediction | null = null;
  latestTremor: TremorEvent | null = null;
  errorMessage: string = '';
  
  // Statistics
  totalTremorsDetected: number = 0;
  totalFreezesDetected: number = 0;
  monitoringStartTime: number = 0;
}
