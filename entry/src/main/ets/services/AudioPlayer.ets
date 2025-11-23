/**
 * AudioPlayer - Manages metronome audio playback for demo mode
 * 
 * CRITICAL: HarmonyOS AVPlayer cannot load resources directly from base/media.
 * 
 * Workaround:
 * 1. Copy ras_metronome.mp3 from Resource Manager to cacheDir on init
 * 2. Load AVPlayer from file://cacheDir/ras_metronome.mp3
 * 3. Set loop mode for continuous playback
 */

import { media } from '@kit.MediaKit';
import { fileIo } from '@kit.CoreFileKit';
import { resourceManager } from '@kit.LocalizationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

const DOMAIN = 0x0011;
const TAG = 'AudioPlayer';

export class AudioPlayer {
  private avPlayer: media.AVPlayer | null = null;
  private context: common.UIAbilityContext | null = null;
  private cachedFilePath: string = '';
  private isInitialized: boolean = false;
  private isPlaying: boolean = false;
  
  private static readonly METRONOME_RESOURCE = 'ras_metronome.mp3';
  private static readonly CACHED_FILENAME = 'metronome_cache.mp3';

  constructor() {
    hilog.info(DOMAIN, TAG, 'AudioPlayer created');
  }

  /**
   * Initialize audio player with context
   * Copies metronome file from resources to cache directory
   */
  public async initialize(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    this.cachedFilePath = `${context.cacheDir}/${AudioPlayer.CACHED_FILENAME}`;
    
    hilog.info(DOMAIN, TAG, `Initializing audio player, cache path: ${this.cachedFilePath}`);
    
    try {
      // Step 1: Copy metronome from resources to cache
      await this.copyResourceToCache();
      
      // Step 2: Create AVPlayer instance
      this.avPlayer = await media.createAVPlayer();
      
      // Step 3: Set up event callbacks
      this.setupCallbacks();
      
      this.isInitialized = true;
      hilog.info(DOMAIN, TAG, '✅ AudioPlayer initialized successfully');
      
    } catch (error) {
      hilog.error(DOMAIN, TAG, `❌ Failed to initialize AudioPlayer: ${JSON.stringify(error)}`);
      throw error;
    }
  }

  /**
   * Copy metronome audio file from resources to cache directory
   * This is required because AVPlayer cannot load from base/media directly
   */
  private async copyResourceToCache(): Promise<void> {
    if (!this.context) {
      throw new Error('Context not set');
    }
    
    try {
      // Get resource manager
      const resMgr: resourceManager.ResourceManager = this.context.resourceManager;
      
      // Read raw file data from resources
      hilog.info(DOMAIN, TAG, `Reading resource: ${AudioPlayer.METRONOME_RESOURCE}`);
      const fileData: Uint8Array = await resMgr.getRawFileContent(AudioPlayer.METRONOME_RESOURCE);
      
      hilog.info(DOMAIN, TAG, `Resource read: ${fileData.byteLength} bytes`);
      
      // Write to cache directory
      const file = fileIo.openSync(
        this.cachedFilePath, 
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC
      );
      
      fileIo.writeSync(file.fd, fileData.buffer);
      fileIo.closeSync(file);
      
      hilog.info(DOMAIN, TAG, `✅ Metronome cached to: ${this.cachedFilePath}`);
      
    } catch (error) {
      hilog.error(DOMAIN, TAG, `❌ Failed to copy resource to cache: ${JSON.stringify(error)}`);
      throw error;
    }
  }

  /**
   * Set up AVPlayer event callbacks
   */
  private setupCallbacks(): void {
    if (!this.avPlayer) {
      return;
    }
    
    // State change callback
    this.avPlayer.on('stateChange', (state: string) => {
      hilog.info(DOMAIN, TAG, `AVPlayer state changed: ${state}`);
      
      if (state === 'playing') {
        this.isPlaying = true;
      } else if (state === 'stopped' || state === 'idle') {
        this.isPlaying = false;
      }
    });
    
    // Error callback
    this.avPlayer.on('error', (error: BusinessError) => {
      hilog.error(DOMAIN, TAG, `AVPlayer error: ${error.code}, ${error.message}`);
      this.isPlaying = false;
    });
    
    // Playback completed callback (for loop detection)
    this.avPlayer.on('endOfStream', () => {
      hilog.info(DOMAIN, TAG, 'Playback completed (loop will restart if enabled)');
    });
  }

  /**
   * Play metronome in continuous loop
   */
  public async playMetronome(): Promise<void> {
    if (!this.isInitialized || !this.avPlayer) {
      hilog.error(DOMAIN, TAG, 'AudioPlayer not initialized');
      throw new Error('AudioPlayer not initialized');
    }
    
    if (this.isPlaying) {
      hilog.warn(DOMAIN, TAG, 'Metronome already playing');
      return;
    }
    
    try {
      hilog.info(DOMAIN, TAG, '🎵 Starting metronome playback');
      
      // Set file URI (must be file:// protocol)
      const fileUri = `file://${this.cachedFilePath}`;
      hilog.info(DOMAIN, TAG, `Loading audio from: ${fileUri}`);
      
      this.avPlayer.url = fileUri;
      
      // Enable loop mode
      this.avPlayer.loop = true;
      
      // Wait for player to be prepared
      await this.waitForState('prepared');
      
      // Start playback
      await this.avPlayer.play();
      
      hilog.info(DOMAIN, TAG, '✅ Metronome playing (loop enabled)');
      
    } catch (error) {
      hilog.error(DOMAIN, TAG, `❌ Failed to play metronome: ${JSON.stringify(error)}`);
      throw error;
    }
  }

  /**
   * Wait for AVPlayer to reach a specific state
   */
  private waitForState(targetState: string, timeoutMs: number = 5000): Promise<void> {
    return new Promise((resolve, reject) => {
      if (!this.avPlayer) {
        reject(new Error('AVPlayer not initialized'));
        return;
      }
      
      const startTime = Date.now();
      
      const checkState = () => {
        if (!this.avPlayer) {
          reject(new Error('AVPlayer destroyed'));
          return;
        }
        
        if (this.avPlayer.state === targetState) {
          resolve();
          return;
        }
        
        if (Date.now() - startTime > timeoutMs) {
          reject(new Error(`Timeout waiting for state: ${targetState}`));
          return;
        }
        
        setTimeout(checkState, 100);
      };
      
      checkState();
    });
  }

  /**
   * Stop playback
   */
  public stop(): void {
    if (!this.avPlayer || !this.isPlaying) {
      return;
    }
    
    try {
      hilog.info(DOMAIN, TAG, '🛑 Stopping metronome');
      this.avPlayer.stop();
      this.isPlaying = false;
      hilog.info(DOMAIN, TAG, '✅ Metronome stopped');
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to stop playback: ${JSON.stringify(error)}`);
    }
  }

  /**
   * Check if audio is currently playing
   */
  public isAudioPlaying(): boolean {
    return this.isPlaying;
  }

  /**
   * Clean up resources
   */
  public async destroy(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Destroying AudioPlayer');
    
    if (this.avPlayer) {
      try {
        if (this.isPlaying) {
          await this.avPlayer.stop();
        }
        await this.avPlayer.release();
        this.avPlayer = null;
      } catch (error) {
        hilog.error(DOMAIN, TAG, `Error during cleanup: ${JSON.stringify(error)}`);
      }
    }
    
    // Clean up cached file
    if (this.cachedFilePath) {
      try {
        if (fileIo.accessSync(this.cachedFilePath)) {
          fileIo.unlinkSync(this.cachedFilePath);
          hilog.info(DOMAIN, TAG, 'Cached audio file deleted');
        }
      } catch (error) {
        hilog.error(DOMAIN, TAG, `Failed to delete cached file: ${error}`);
      }
    }
    
    this.isInitialized = false;
    this.isPlaying = false;
    hilog.info(DOMAIN, TAG, '✅ AudioPlayer destroyed');
  }
}
