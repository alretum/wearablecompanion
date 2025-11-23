/**
 * AudioPlayer - Manages metronome audio playback for demo mode
 * 
 * CRITICAL: HarmonyOS AVPlayer cannot load resources directly from rawfile.
 * 
 * Workaround:
 * 1. Copy ras_metronome.mp3 from resources/rawfile to cacheDir on init
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
    hilog.info(DOMAIN, TAG, `Context type: ${typeof context}, resourceManager: ${context.resourceManager !== undefined}`);
    
    try {
      // Step 1: Copy metronome from resources to cache
      hilog.info(DOMAIN, TAG, 'Step 1: Copying metronome file to cache...');
      await this.copyResourceToCache();
      hilog.info(DOMAIN, TAG, '✅ Step 1 complete: File copied to cache');
      
      // Step 2: Create AVPlayer instance
      hilog.info(DOMAIN, TAG, 'Step 2: Creating AVPlayer instance...');
      this.avPlayer = await media.createAVPlayer();
      hilog.info(DOMAIN, TAG, '✅ Step 2 complete: AVPlayer created');
      
      // Step 3: Set up event callbacks
      hilog.info(DOMAIN, TAG, 'Step 3: Setting up callbacks...');
      this.setupCallbacks();
      hilog.info(DOMAIN, TAG, '✅ Step 3 complete: Callbacks registered');
      
      this.isInitialized = true;
      hilog.info(DOMAIN, TAG, '✅✅✅ AudioPlayer initialized successfully');
      
    } catch (error) {
      const errorMsg = `Failed to initialize AudioPlayer: ${JSON.stringify(error)}`;
      hilog.error(DOMAIN, TAG, `❌ ${errorMsg}`);
      throw new Error(errorMsg);
    }
  }

  /**
   * Copy metronome audio file from resources/rawfile to cache directory
   * This is required because AVPlayer cannot load from rawfile directly
   */
  private async copyResourceToCache(): Promise<void> {
    if (!this.context) {
      throw new Error('Context not set');
    }
    
    try {
      // Get resource manager
      const resMgr: resourceManager.ResourceManager = this.context.resourceManager;
      hilog.info(DOMAIN, TAG, `Resource manager obtained: ${resMgr !== null}`);
      
      // Method 1: Try using getRawFd (more reliable than getRawFileContent)
      hilog.info(DOMAIN, TAG, `Attempting getRawFd for: ${AudioPlayer.METRONOME_RESOURCE}`);
      
      try {
        const rawFd = await resMgr.getRawFd(AudioPlayer.METRONOME_RESOURCE);
        hilog.info(DOMAIN, TAG, `✅ Got raw FD - fd: ${rawFd.fd}, offset: ${rawFd.offset}, length: ${rawFd.length}`);
        
        // Read from the file descriptor with correct offset
        const buffer = new ArrayBuffer(rawFd.length);
        const readBytes = fileIo.readSync(rawFd.fd, buffer, { 
          offset: rawFd.offset, 
          length: rawFd.length 
        });
        
        hilog.info(DOMAIN, TAG, `Read ${readBytes} bytes from raw FD`);
        
        // Write to cache directory
        const outFile = fileIo.openSync(
          this.cachedFilePath, 
          fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC
        );
        
        const writeBytes = fileIo.writeSync(outFile.fd, buffer);
        fileIo.closeSync(outFile);
        
        hilog.info(DOMAIN, TAG, `Wrote ${writeBytes} bytes to cache`);
        
        // Close the raw file descriptor
        resMgr.closeRawFd(AudioPlayer.METRONOME_RESOURCE);
        
        hilog.info(DOMAIN, TAG, `✅✅ Metronome cached successfully to: ${this.cachedFilePath}`);
        return;
        
      } catch (fdError) {
        // Fallback: Try getRawFileContent
        hilog.warn(DOMAIN, TAG, `getRawFd failed (${JSON.stringify(fdError)}), trying getRawFileContent...`);
        
        const fileData: Uint8Array = await resMgr.getRawFileContent(AudioPlayer.METRONOME_RESOURCE);
        hilog.info(DOMAIN, TAG, `✅ Resource read via getRawFileContent: ${fileData.byteLength} bytes`);
        
        const file = fileIo.openSync(
          this.cachedFilePath, 
          fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC
        );
        
        fileIo.writeSync(file.fd, fileData.buffer);
        fileIo.closeSync(file);
        
        hilog.info(DOMAIN, TAG, `✅✅ Metronome cached to: ${this.cachedFilePath}`);
      }
      
    } catch (error) {
      const errorMsg = `Failed to copy resource to cache: ${JSON.stringify(error)}`;
      hilog.error(DOMAIN, TAG, `❌ ${errorMsg}`);
      throw new Error(errorMsg);
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
    hilog.info(DOMAIN, TAG, `🎵 playMetronome called - isInitialized: ${this.isInitialized}, avPlayer: ${this.avPlayer !== null}, isPlaying: ${this.isPlaying}`);
    
    if (!this.isInitialized || !this.avPlayer) {
      const error = 'AudioPlayer not initialized';
      hilog.error(DOMAIN, TAG, `❌ ${error}`);
      throw new Error(error);
    }
    
    if (this.isPlaying) {
      hilog.warn(DOMAIN, TAG, 'Metronome already playing');
      return;
    }
    
    try {
      hilog.info(DOMAIN, TAG, '🎵 Starting metronome playback - current AVPlayer state: ' + this.avPlayer.state);
      
      // Set file URI (must be file:// protocol)
      const fileUri = `file://${this.cachedFilePath}`;
      hilog.info(DOMAIN, TAG, `Setting audio URL: ${fileUri}`);
      
      this.avPlayer.url = fileUri;
      hilog.info(DOMAIN, TAG, 'URL set, enabling loop mode');
      
      // Enable loop mode
      this.avPlayer.loop = true;
      hilog.info(DOMAIN, TAG, 'Loop enabled, waiting for prepared state...');
      
      // Wait for player to be prepared
      await this.waitForState('prepared');
      hilog.info(DOMAIN, TAG, '✅ Player prepared, calling play()...');
      
      // Start playback
      await this.avPlayer.play();
      
      hilog.info(DOMAIN, TAG, '✅✅✅ Metronome playing (loop enabled)');
      
    } catch (error) {
      const errorMsg = `Failed to play metronome: ${JSON.stringify(error)}`;
      hilog.error(DOMAIN, TAG, `❌ ${errorMsg}`);
      throw new Error(errorMsg);
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
