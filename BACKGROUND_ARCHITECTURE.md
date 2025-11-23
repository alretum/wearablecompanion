# Background Service Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          WearableCompanion App                               │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                              App Lifecycle                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────────┐         ┌────────────────────────────────────────┐   │
│  │                  │         │                                        │   │
│  │  EntryAbility    │ starts  │  BackgroundMonitoringService           │   │
│  │  (UI Layer)      ├────────►│  (Service Extension)                   │   │
│  │                  │         │                                        │   │
│  └────────┬─────────┘         └─────────────┬──────────────────────────┘   │
│           │                                  │                              │
│           │ connects                         │ uses                         │
│           │                                  │                              │
│           │                   ┌──────────────▼──────────────┐              │
│           └──────────────────►│                             │              │
│                               │   MonitoringService         │              │
│                               │   (Singleton)               │              │
│                               │                             │              │
│                               └──────────┬──────────────────┘              │
│                                          │                                  │
│                                          │ manages                          │
│                                          │                                  │
│          ┌───────────────────────────────┼───────────────────────┐         │
│          │                               │                       │         │
│          │                               │                       │         │
│  ┌───────▼────────┐            ┌─────────▼──────┐      ┌────────▼──────┐  │
│  │ SensorManager  │            │ TremorDetector │      │ APIService    │  │
│  │                │            │                │      │               │  │
│  │ - Accel 50Hz   │            │ - 60s bursts   │      │ - Freeze API  │  │
│  │ - Gyro 50Hz    │            │ - 10s samples  │      │ - HR API      │  │
│  │ - HR 1Hz       │            │ - Analysis     │      │ - Sync API    │  │
│  └────────────────┘            └────────────────┘      └───────────────┘  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                         State Transitions                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────┐                                                            │
│  │  APP OPEN   │                                                            │
│  └──────┬──────┘                                                            │
│         │                                                                    │
│         │ onCreate()                                                         │
│         ▼                                                                    │
│  ┌─────────────────────────────────────────────────┐                        │
│  │  Background Service STARTS                      │                        │
│  │  ✓ MonitoringService initialized                │                        │
│  │  ✓ Sensors start collecting                     │                        │
│  │  ✓ Continuous task registered                   │                        │
│  │  ✓ UI shows real-time data                      │                        │
│  └────────────┬────────────────────────────────────┘                        │
│               │                                                              │
│               │ onBackground() / onDestroy()                                 │
│               ▼                                                              │
│  ┌─────────────────────────────────────────────────┐                        │
│  │  APP CLOSED / MINIMIZED                         │                        │
│  │  ✓ UI disconnects from service                  │                        │
│  │  ✓ Background service KEEPS RUNNING             │                        │
│  │  ✓ Sensors continue collecting                  │                        │
│  │  ✓ Tremor detection every 60s                   │                        │
│  │  ✓ Freeze prediction real-time                  │                        │
│  │  ✓ API sync every 5 minutes                     │                        │
│  │  ✓ HR aggregation every minute                  │                        │
│  └────────────┬────────────────────────────────────┘                        │
│               │                                                              │
│               │ User clicks "Stop" OR Manual stop                            │
│               ▼                                                              │
│  ┌─────────────────────────────────────────────────┐                        │
│  │  SERVICE STOPPED                                │                        │
│  │  ✓ stopBackgroundService() called               │                        │
│  │  ✓ Sensors stop                                 │                        │
│  │  ✓ Final data sync                              │                        │
│  │  ✓ Continuous task unregistered                 │                        │
│  │  ✓ Service destroyed                            │                        │
│  └─────────────────────────────────────────────────┘                        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                    Background Operations Timeline                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Time:  0s        60s       120s      180s      240s      300s              │
│         │         │         │         │         │         │                 │
│  Tremor │─────────●─────────●─────────●─────────●─────────●                │
│  Detect │    10s burst  10s burst  10s burst  10s burst  10s burst         │
│         │                                                                    │
│  Heart  │────●────●────●────●────●────●────●────●────●────●                │
│  Rate   │   (every 60s: aggregate and report)                               │
│  Aggr.  │                                                                    │
│         │                                                                    │
│  API    │─────────────────────────────────────────────────●                │
│  Sync   │                                             (300s = 5 min)         │
│         │                                                                    │
│  Freeze │●─────●─────────●────────────────────●─────────────●              │
│  Detect │  (real-time, immediate alert + GPS on detection)                  │
│         │                                                                    │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                      Data Flow (Background Mode)                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────┐                                                           │
│  │   Sensors    │                                                           │
│  │              │                                                           │
│  │ Accel 50Hz   │──┐                                                        │
│  │ Gyro 50Hz    │──┼──► SensorManager ──► TremorDetector ─┐                │
│  │ HR 1Hz       │──┘                                       │                │
│  └──────────────┘                     PredictionAlgorithm ─┤                │
│                                                            │                │
│                                    HeartRateLogger ────────┤                │
│                                                            │                │
│                                    DataCollectionLogger ───┤                │
│                                                            │                │
│                                                            ▼                │
│  ┌──────────────────────────────────────────────────────────────┐          │
│  │                       APIService                             │          │
│  │                                                              │          │
│  │  • sendFreezeAlert() ────► AWS Lambda (immediate)           │          │
│  │  • uploadHeartRateReport() ─► Supabase (every 5min)         │          │
│  │  • syncReportFile() ────────► AWS S3 (every 5min)           │          │
│  │                                                              │          │
│  └──────────────────────────────────────────────────────────────┘          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                          File Structure                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  entry/src/main/ets/                                                        │
│  ├── entryability/                                                          │
│  │   └── EntryAbility.ets          ← Modified (starts background service)  │
│  ├── serviceability/                                                        │
│  │   └── BackgroundMonitoringService.ets  ← NEW (background service)       │
│  ├── services/                                                              │
│  │   ├── MonitoringService.ets     ← Shared singleton                      │
│  │   ├── APIService.ets                                                    │
│  │   ├── HeartRateLogger.ets                                               │
│  │   └── DataCollectionLogger.ets                                          │
│  ├── sensors/                                                               │
│  │   └── SensorManager.ets                                                 │
│  ├── algorithms/                                                            │
│  │   ├── TremorDetector.ets                                                │
│  │   └── PredictionAlgorithm.ets                                           │
│  └── config/                                                                │
│      └── AppConfig.ets                                                      │
│                                                                              │
│  entry/src/main/                                                            │
│  ├── module.json5                   ← Modified (registered service)        │
│  └── resources/base/element/                                                │
│      └── string.json                ← Modified (added description)         │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```
