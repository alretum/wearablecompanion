/**
 * DemoManager - "Guardian Angel" Demo Mode Controller
 * 
 * Orchestrates the FoG demo sequence:
 * 1. Detect violent wrist shake (Energy > 6.0 m/s²)
 * 2. T=0s: Visual (red screen), Haptic (vibration), Audio (metronome)
 * 3. T=15s: Trigger backend call via Twilio
 * 
 * This is a Singleton to persist state across UI updates.
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { http } from '@kit.NetworkKit';
import { vibrator } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AudioPlayer } from './AudioPlayer';
import { AppConfig } from '../config/AppConfig';
import { common } from '@kit.AbilityKit';

const DOMAIN = 0x0010;
const TAG = 'DemoManager';

// DEMO CONFIGURATION
const DEMO_DELAY_MS = 15000; // 15 seconds until phone call trigger

export enum DemoState {
  INACTIVE = 'INACTIVE',
  INTERVENTION = 'INTERVENTION',
  CALLING_GUARDIAN = 'CALLING_GUARDIAN',
  CALL_TRIGGERED = 'CALL_TRIGGERED',
  ERROR = 'ERROR'
}

interface VibrateTime {
  type: 'time';
  duration: number;
}

export class DemoManager {
  private static instance: DemoManager | null = null;
  
  // State management
  private isDemoActive: boolean = false;
  private currentState: DemoState = DemoState.INACTIVE;
  private timerId: number = -1;
  
  // Services
  private audioPlayer: AudioPlayer | null = null;
  private context: common.UIAbilityContext | null = null;
  
  // State callbacks for UI updates
  private stateCallbacks: ((state: DemoState) => void)[] = [];
  
  private constructor() {
    hilog.info(DOMAIN, TAG, '🛡️ Guardian Angel Demo Manager initialized');
  }
  
  /**
   * Get singleton instance
   */
  public static getInstance(): DemoManager {
    if (DemoManager.instance === null) {
      DemoManager.instance = new DemoManager();
    }
    return DemoManager.instance;
  }
  
  /**
   * Initialize with context (required for audio playback)
   */
  public async initialize(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    this.audioPlayer = new AudioPlayer();
    await this.audioPlayer.initialize(context);
    hilog.info(DOMAIN, TAG, '✅ DemoManager initialized with context');
  }
  
  /**
   * Register callback for state changes
   */
  public onStateChange(callback: (state: DemoState) => void): void {
    this.stateCallbacks.push(callback);
  }
  
  /**
   * Get current demo state
   */
  public getState(): DemoState {
    return this.currentState;
  }
  
  /**
   * Check if demo is currently active
   */
  public isActive(): boolean {
    return this.isDemoActive;
  }
  
  /**
   * Start the demo sequence
   * 
   * PHASE 1 (T=0s): Immediate intervention
   * - Visual: Red screen with "BREATHE. STEP TO THE BEAT."
   * - Haptic: Continuous vibration
   * - Audio: Play metronome loop
   * 
   * PHASE 2 (T=15s): Trigger phone call
   * - HTTP POST to backend/Twilio
   * - Update UI: "Calling Guardian..."
   */
  public async startDemoSequence(): Promise<void> {
    if (this.isDemoActive) {
      hilog.warn(DOMAIN, TAG, '⚠️ Demo already active, ignoring trigger');
      return;
    }
    
    hilog.info(DOMAIN, TAG, '🚨 DEMO SEQUENCE STARTED - FoG Incident Detected');
    
    this.isDemoActive = true;
    this.updateState(DemoState.INTERVENTION);
    
    // PHASE 1: Immediate Intervention (T=0s)
    await this.startInterventionPhase();
    
    // PHASE 2: Schedule phone call trigger (T=15s)
    this.schedulePhoneCall();
  }
  
  /**
   * PHASE 1: Start immediate intervention
   */
  private async startInterventionPhase(): Promise<void> {
    hilog.info(DOMAIN, TAG, '⚡ PHASE 1: Starting immediate intervention');
    
    try {
      // Start metronome audio
      if (this.audioPlayer) {
        await this.audioPlayer.playMetronome();
        hilog.info(DOMAIN, TAG, '🎵 Metronome started');
      }
      
      // Start continuous vibration
      this.startVibration();
      hilog.info(DOMAIN, TAG, '📳 Vibration started');
      
      hilog.info(DOMAIN, TAG, '✅ Intervention phase active - Visual/Audio/Haptic feedback running');
    } catch (error) {
      hilog.error(DOMAIN, TAG, `❌ Failed to start intervention: ${error}`);
    }
  }
  
  /**
   * Start continuous vibration pattern
   */
  private startVibration(): void {
    try {
      // Create a strong, noticeable vibration pattern
      // 500ms ON, 200ms OFF, repeating
      const vibrateEffect: VibrateTime = {
        type: 'time',
        duration: 500
      };
      
      vibrator.startVibration(vibrateEffect, {
        usage: 'alarm'
      }, (error: BusinessError) => {
        if (error) {
          hilog.error(DOMAIN, TAG, `Vibration error: ${error.code}, ${error.message}`);
        }
      });
      
      // Schedule next vibration pulse
      setTimeout(() => {
        if (this.isDemoActive) {
          this.startVibration(); // Recursive call for continuous vibration
        }
      }, 700); // Total cycle: 500ms vibrate + 200ms pause
      
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to start vibration: ${error}`);
    }
  }
  
  /**
   * Schedule the phone call trigger for T=15s
   */
  private schedulePhoneCall(): void {
    hilog.info(DOMAIN, TAG, `⏰ Scheduling phone call trigger in ${DEMO_DELAY_MS}ms`);
    
    this.timerId = setTimeout(() => {
      this.triggerPhoneCall();
    }, DEMO_DELAY_MS);
  }
  
  /**
   * PHASE 2: Trigger backend to initiate phone call
   */
  private async triggerPhoneCall(): Promise<void> {
    hilog.info(DOMAIN, TAG, '📞 PHASE 2: Triggering phone call to guardian');
    
    this.updateState(DemoState.CALLING_GUARDIAN);
    
    try {
      // Prepare HTTP request
      const httpRequest = http.createHttp();
      
      const requestPayload = {
        deviceId: 'WATCH_DEMO',
        reason: 'FOG_INCIDENT',
        timestamp: new Date().toISOString(),
        location: 'DEMO_MODE'
      };
      
      hilog.info(DOMAIN, TAG, `Sending POST to ${AppConfig.DEMO_CALL_ENDPOINT}`);
      
      const response = await httpRequest.request(
        AppConfig.DEMO_CALL_ENDPOINT,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json'
          },
          extraData: JSON.stringify(requestPayload),
          connectTimeout: 10000,
          readTimeout: 10000
        }
      );
      
      if (response.responseCode === 200 || response.responseCode === 201) {
        hilog.info(DOMAIN, TAG, '✅ Phone call triggered successfully');
        this.updateState(DemoState.CALL_TRIGGERED);
      } else {
        hilog.error(DOMAIN, TAG, `❌ Call trigger failed: HTTP ${response.responseCode}`);
        this.updateState(DemoState.ERROR);
      }
      
      httpRequest.destroy();
      
    } catch (error) {
      hilog.error(DOMAIN, TAG, `❌ Call Failed - Network Error: ${JSON.stringify(error)}`);
      this.updateState(DemoState.ERROR);
    }
  }
  
  /**
   * Stop the demo and reset all state
   * Can be called manually or after demo completes
   */
  public stopDemo(): void {
    hilog.info(DOMAIN, TAG, '🛑 Stopping demo sequence');
    
    // Clear timer if scheduled
    if (this.timerId !== -1) {
      clearTimeout(this.timerId);
      this.timerId = -1;
    }
    
    // Stop audio
    if (this.audioPlayer) {
      this.audioPlayer.stop();
      hilog.info(DOMAIN, TAG, '🎵 Metronome stopped');
    }
    
    // Stop vibration
    try {
      vibrator.stopVibration();
      hilog.info(DOMAIN, TAG, '📳 Vibration stopped');
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to stop vibration: ${error}`);
    }
    
    // Reset state
    this.isDemoActive = false;
    this.updateState(DemoState.INACTIVE);
    
    hilog.info(DOMAIN, TAG, '✅ Demo reset complete - Ready for next run');
  }
  
  /**
   * Update state and notify callbacks
   */
  private updateState(newState: DemoState): void {
    this.currentState = newState;
    hilog.info(DOMAIN, TAG, `📊 State changed: ${newState}`);
    
    // Notify all registered callbacks
    this.stateCallbacks.forEach(callback => {
      try {
        callback(newState);
      } catch (error) {
        hilog.error(DOMAIN, TAG, `Callback error: ${error}`);
      }
    });
  }
  
  /**
   * Cleanup resources
   */
  public destroy(): void {
    this.stopDemo();
    if (this.audioPlayer) {
      this.audioPlayer.destroy();
    }
    this.stateCallbacks = [];
    hilog.info(DOMAIN, TAG, '🗑️ DemoManager destroyed');
  }
}
