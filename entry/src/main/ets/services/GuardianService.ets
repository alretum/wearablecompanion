/**
 * GuardianService - Continuous FoG Detection & Audio Intervention
 * 
 * Global singleton service that runs persistently in the background.
 * Monitors accelerometer at 50 Hz and triggers audio metronome on FoG detection.
 * 
 * Responsibilities:
 * - Initialize audio asset (copy from resources to cache)
 * - Continuous sensor monitoring at 50 Hz
 * - Real-time FoG detection using FreezeDetector
 * - Audio playback and haptic feedback on detection
 * - Cloud event reporting (FOG_STARTED, FOG_ENDED)
 */

import { sensor } from '@kit.SensorServiceKit';
import { media } from '@kit.MediaKit';
import { vibrator } from '@kit.SensorServiceKit';
import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { FreezeDetector } from '../algorithms/FreezeDetector.ets';
import { AccelerometerData } from '../sensors/SensorData.ets';
import { APIService } from '../connectivity/APIService';

const DOMAIN = 0x0021;
const TAG = 'GuardianService';

interface VibrateTime {
  type: 'time';
  duration: number;
}

interface CloudEvent {
  type: string;
  timestamp: string;
  duration?: number;
}

export class GuardianService {
  private static instance: GuardianService | null = null;

  private freezeDetector: FreezeDetector;
  private apiService: APIService;
  private context: common.UIAbilityContext | null = null;

  // Audio components
  private avPlayer: media.AVPlayer | null = null;
  private audioPath: string = '';
  private audioInitialized: boolean = false;

  // Sensor state
  private isMonitoring: boolean = false;
  private accelSubscribed: boolean = false;
  private sampleCount: number = 0;

  // FoG state tracking
  private currentlyFrozen: boolean = false;
  private freezeStartTime: number = 0;

  private constructor() {
    this.freezeDetector = new FreezeDetector();
    this.apiService = new APIService();
    hilog.info(DOMAIN, TAG, 'GuardianService initialized');
  }

  /**
   * Get singleton instance
   */
  public static getInstance(): GuardianService {
    if (GuardianService.instance === null) {
      GuardianService.instance = new GuardianService();
    }
    return GuardianService.instance;
  }

  /**
   * Initialize the service with app context
   */
  public async initialize(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    hilog.info(DOMAIN, TAG, 'Initializing GuardianService...');

    try {
      await this.initAudio();
      hilog.info(DOMAIN, TAG, 'GuardianService ready');
    } catch (error) {
      const errorMsg = `Initialization failed: ${error}`;
      hilog.error(DOMAIN, TAG, errorMsg);
      throw new Error(errorMsg);
    }
  }

  /**
   * CRITICAL: Audio Initialization Workaround
   * 
   * AVPlayer cannot access resources/base/media directly.
   * This function copies the audio file to the app's cache directory.
   */
  private async initAudio(): Promise<void> {
    if (!this.context) {
      throw new Error('Context not initialized');
    }

    try {
      hilog.info(DOMAIN, TAG, 'Initializing audio asset...');

      // Step 1: Get resource content
      const resourceManager = this.context.resourceManager;
      const mediaContent = await resourceManager.getMediaContent($r('app.media.ras_metronome').id);
      
      hilog.info(DOMAIN, TAG, `Resource loaded: ${mediaContent.byteLength} bytes`);

      // Step 2: Define target path in cache
      this.audioPath = `${this.context.cacheDir}/ras_metronome.mp3`;
      hilog.info(DOMAIN, TAG, `Target path: ${this.audioPath}`);

      // Step 3: Write file to cache
      const file = fs.openSync(this.audioPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
      fs.writeSync(file.fd, mediaContent.buffer);
      fs.closeSync(file);
      
      hilog.info(DOMAIN, TAG, 'Audio file written to cache');

      // Step 4: Initialize AVPlayer
      this.avPlayer = await media.createAVPlayer();
      
      // Set up callbacks
      this.avPlayer.on('stateChange', (state: string) => {
        hilog.info(DOMAIN, TAG, `AVPlayer state: ${state}`);
      });

      this.avPlayer.on('error', (error: Error) => {
        hilog.error(DOMAIN, TAG, `AVPlayer error: ${error.message}`);
      });

      // Step 5: Set URL and prepare
      const fileUrl = `file://${this.audioPath}`;
      this.avPlayer.url = fileUrl;
      hilog.info(DOMAIN, TAG, `AVPlayer URL set: ${fileUrl}`);

      // Step 6: Enable looping
      this.avPlayer.loop = true;

      // Prepare the player
      await this.preparePlayer();

      this.audioInitialized = true;
      hilog.info(DOMAIN, TAG, '✓ Audio initialization complete');

    } catch (error) {
      const errorMsg = `Audio initialization failed: ${JSON.stringify(error)}`;
      hilog.error(DOMAIN, TAG, errorMsg);
      throw new Error(errorMsg);
    }
  }

  /**
   * Prepare the AVPlayer for playback
   */
  private preparePlayer(): Promise<void> {
    return new Promise((resolve, reject) => {
      if (!this.avPlayer) {
        reject(new Error('AVPlayer not initialized'));
        return;
      }

      const onPrepared = () => {
        hilog.info(DOMAIN, TAG, 'AVPlayer prepared');
        this.avPlayer?.off('stateChange', onPrepared);
        resolve();
      };

      this.avPlayer.on('stateChange', onPrepared);
      this.avPlayer.prepare();

      // Timeout after 5 seconds
      setTimeout(() => {
        this.avPlayer?.off('stateChange', onPrepared);
        reject(new Error('AVPlayer preparation timeout'));
      }, 5000);
    });
  }

  /**
   * Start continuous FoG monitoring
   */
  public startMonitoring(): void {
    if (this.isMonitoring) {
      hilog.warn(DOMAIN, TAG, 'Already monitoring');
      return;
    }

    if (!this.audioInitialized) {
      hilog.error(DOMAIN, TAG, 'Cannot start - audio not initialized');
      return;
    }

    hilog.info(DOMAIN, TAG, 'Starting continuous FoG monitoring at 50 Hz...');

    try {
      // Reset sample counter
      this.sampleCount = 0;
      
      // Subscribe to accelerometer at 50 Hz (20ms interval)
      sensor.on(sensor.SensorId.ACCELEROMETER, (data: sensor.AccelerometerResponse) => {
        this.handleAccelerometer(data);
      }, { interval: 20000 }); // 20ms = 50 Hz

      this.accelSubscribed = true;
      this.isMonitoring = true;

      hilog.info(DOMAIN, TAG, '✓ FoG monitoring started - waiting for accelerometer data...');

    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to start monitoring: ${error}`);
      this.isMonitoring = false;
    }
  }

  /**
   * Stop FoG monitoring
   */
  public stopMonitoring(): void {
    if (!this.isMonitoring) {
      hilog.warn(DOMAIN, TAG, 'Not monitoring');
      return;
    }

    hilog.info(DOMAIN, TAG, 'Stopping FoG monitoring...');

    try {
      // Unsubscribe from accelerometer
      if (this.accelSubscribed) {
        sensor.off(sensor.SensorId.ACCELEROMETER);
        this.accelSubscribed = false;
      }

      // Stop audio if playing
      if (this.currentlyFrozen) {
        this.stopIntervention();
      }

      this.isMonitoring = false;
      hilog.info(DOMAIN, TAG, '✓ FoG monitoring stopped');

    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to stop monitoring: ${error}`);
    }
  }

  /**
   * Handle accelerometer data and run FoG detection
   */
  private handleAccelerometer(data: sensor.AccelerometerResponse): void {
    const sample: AccelerometerData = {
      x: data.x,
      y: data.y,
      z: data.z,
      timestamp: data.timestamp
    };

    // Debug: Log first few samples to confirm data flow
    if (!this.sampleCount) {
      this.sampleCount = 0;
    }
    this.sampleCount++;
    
    if (this.sampleCount <= 5) {
      hilog.info(DOMAIN, TAG, 
        `Accel sample ${this.sampleCount}: x=${data.x.toFixed(3)}, y=${data.y.toFixed(3)}, z=${data.z.toFixed(3)}`);
    }

    // Run FoG detection
    const fogDetected = this.freezeDetector.detectFreeze(sample);

    // Handle state transitions
    if (fogDetected && !this.currentlyFrozen) {
      // FoG started
      this.onFreezeStarted();
    } else if (!fogDetected && this.currentlyFrozen) {
      // FoG ended
      this.onFreezeEnded();
    }
  }

  /**
   * Handle FoG detection (start intervention)
   */
  private onFreezeStarted(): void {
    this.currentlyFrozen = true;
    this.freezeStartTime = Date.now();

    hilog.info(DOMAIN, TAG, '🚨 [FOG_STARTED] Initiating intervention...');

    // Start audio playback
    this.playAudio();

    // Trigger haptic feedback
    this.triggerHaptic();

    // Send cloud event
    this.sendCloudEvent('FOG_STARTED');
  }

  /**
   * Handle FoG clearance (stop intervention)
   */
  private onFreezeEnded(): void {
    const duration = Date.now() - this.freezeStartTime;
    this.currentlyFrozen = false;

    hilog.info(DOMAIN, TAG, `✓ [FOG_ENDED] Duration: ${duration}ms`);

    // Stop audio playback
    this.stopIntervention();

    // Send cloud event
    this.sendCloudEvent('FOG_ENDED', duration);
  }

  /**
   * Play metronome audio
   */
  private playAudio(): void {
    if (!this.avPlayer) {
      hilog.error(DOMAIN, TAG, 'Cannot play - AVPlayer not initialized');
      return;
    }

    try {
      this.avPlayer.play();
      hilog.info(DOMAIN, TAG, '🔊 Playing metronome audio (looping)');
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to play audio: ${error}`);
    }
  }

  /**
   * Stop audio intervention
   */
  private stopIntervention(): void {
    if (!this.avPlayer) return;

    try {
      this.avPlayer.pause();
      hilog.info(DOMAIN, TAG, '🔇 Audio stopped');
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to stop audio: ${error}`);
    }
  }

  /**
   * Trigger haptic feedback
   */
  private triggerHaptic(): void {
    try {
      const vibrateTime: VibrateTime = {
        type: 'time',
        duration: 500 // 500ms vibration
      };
      
      vibrator.startVibration(vibrateTime, {
        usage: 'alarm'
      });

      hilog.info(DOMAIN, TAG, '📳 Haptic feedback triggered');
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to trigger haptic: ${error}`);
    }
  }

  /**
   * Send cloud event
   */
  private sendCloudEvent(eventType: 'FOG_STARTED' | 'FOG_ENDED', duration?: number): void {
    // TODO: Implement cloud event API call
    const event: CloudEvent = {
      type: eventType,
      timestamp: new Date().toISOString(),
      duration: duration
    };

    hilog.info(DOMAIN, TAG, `☁️ Cloud event: ${JSON.stringify(event)}`);
    
    // Note: Extend APIService to add FoG event endpoint
  }

  /**
   * Get current monitoring state
   */
  public isActive(): boolean {
    return this.isMonitoring;
  }

  /**
   * Get current FoG state
   */
  public isFogActive(): boolean {
    return this.currentlyFrozen;
  }

  /**
   * Clean up resources
   */
  public async cleanup(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Cleaning up GuardianService...');

    this.stopMonitoring();

    if (this.avPlayer) {
      try {
        await this.avPlayer.release();
        this.avPlayer = null;
      } catch (error) {
        hilog.error(DOMAIN, TAG, `Failed to release AVPlayer: ${error}`);
      }
    }

    hilog.info(DOMAIN, TAG, 'GuardianService cleaned up');
  }
}
