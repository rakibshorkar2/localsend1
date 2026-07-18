# LocalSend Architecture Analysis

## 1. Overall Architecture

LocalSend is a **cross-platform, open-source file-sharing application** (AirDrop alternative) built with a **multi-layer, multi-language architecture**:

- **Frontend (Dart/Flutter 3.41.9):** UI rendering, state management, HTTP server (receive), platform integrations
- **Backend Logic (Rust):** HTTP client/server (core protocol v2/v3), WebRTC signaling/transfer, cryptographic operations (certificate verification, token signing, nonce exchange)
- **Bridge:** `flutter_rust_bridge` v2.12.0 enables Dart-to-Rust FFI calls
- **Multi-Isolate (Dart):** Heavy work (file upload, multicast discovery, HTTP scan discovery) runs in **typed child isolates** via the local `typed_isolates` package
- **Standalone Rust Server:** A separate CLI server (`server/`) using `axum` serves as a headless relay
- **Rust Core Library (`packages/core/`):** Shared Rust crate (`localsend`) used by both the Flutter app (via `rust_builder/`) and the standalone server

The data flow follows: **UI (Refena state) -> Dart isolate coordination -> Rust FFI calls (HTTP client) -> network -> remote peer's Dart HTTP server or Rust core server.**

## 2. Flutter Version

- **Flutter 3.41.9** (managed via FVM in `.fvmrc`)
- SDK constraint: `^3.11.0`

## 3. Dart Version

- **Dart ^3.11.0** (inferred from pubspec environment SDK constraint)

## 4. Folder Structure

```
localsend/
├── .fvmrc                          # Flutter version pinning
├── app/                            # Main Flutter application
│   ├── lib/
│   │   ├── config/                 # App initialization, theme, Refena setup
│   │   ├── gen/                    # Generated code (i18n strings, assets)
│   │   ├── isolate/                # Multi-isolate orchestration layer
│   │   │   ├── model/              # Isolate-shared models (Device, DTOs)
│   │   │   ├── src/isolate/        # Parent/child isolate controllers
│   │   │   │   ├── parent/         # Parent isolate state & actions
│   │   │   │   └── child/          # Child isolate implementations (multicast, HTTP scan, upload)
│   │   │   ├── src/task/           # Task implementations run inside isolates
│   │   │   │   ├── discovery/      # Multicast & HTTP discovery tasks
│   │   │   │   └── upload/         # HTTP upload task
│   │   │   ├── api_route_builder.dart
│   │   │   ├── constants.dart      # Protocol version, default port, multicast group
│   │   │   └── isolate.dart        # Re-exports
│   │   ├── model/                  # Domain models (cross_file, state, persistence)
│   │   ├── pages/                  # UI screens
│   │   ├── provider/               # Refena state providers
│   │   │   ├── network/            # Networking providers (nearby devices, send, server, WebRTC)
│   │   │   └── selection/          # Selected files providers
│   │   ├── rust/                   # flutter_rust_bridge generated bindings
│   │   ├── util/                   # Utilities (native helpers, UI, security, i18n)
│   │   └── widget/                 # Reusable widgets (watchers, dialogs, list tiles)
│   ├── rust/                       # Rust source for the Flutter app (via flutter_rust_bridge)
│   ├── rust_builder/               # Cargo build integration
│   └── test/
├── cli/                            # Standalone Rust CLI (minimal, WIP)
├── server/                         # Standalone Rust HTTP server (axum-based relay)
├── packages/
│   ├── core/                       # Shared Rust library (localsend) - HTTP, crypto, WebRTC, models
│   └── typed_isolates/             # Custom package for type-safe Dart isolate communication
└── submodules/                     # Git submodules
```

## 5. State Management

**Framework: Refena** (`refena_flutter: 3.2.1` + `refena_inspector_client: 2.1.1`)

Refena is a state management library inspired by Riverpod with Redux-style actions. Three provider types are used:

- **`NotifierProvider`** — simple mutable state (e.g., `settingsProvider`, `sendProvider`, `serverProvider`)
- **`ReduxProvider`** — immutable state with Redux-style actions dispatched via `.dispatch()` (e.g., `nearbyDevicesProvider`, `parentIsolateProvider`)
- **`ViewProvider`** — derived/read-only state (e.g., `httpTargetDiscoveryProvider`)
- **`ChangeNotifierProvider`** — for performance-critical, frequently-updated state (e.g., `progressProvider`)

Actions are dispatched either as:
- **`ReduxAction`** — synchronous state mutation
- **`AsyncReduxAction`** — async with state mutation
- **`AsyncGlobalAction`** — async actions that don't belong to a specific provider

Debugging includes `RefenaInspectorObserver` and `RefenaTracingObserver` (excluded for high-frequency events like discovery logs, local IP, progress).

## 6. Dependency Injection

DI is **built into Refena's provider system** — there is no separate DI container. Dependencies are wired through:

1. **Provider overrides** at initialization (`persistenceProvider`, `deviceRawInfoProvider`, etc.)
2. **Constructor injection** via provider factories (e.g., `SettingsService(ref.read(persistenceProvider))`)
3. **`Provider` for singletons** (e.g., `httpProvider`, `persistenceProvider`)
4. **`ref.read()` / `ref.watch()`** inside providers and widgets for dependency resolution

The `RefenaContainer` is created in `preInit()` and passed to `RefenaScope` wrapping the app.

## 7. Navigation Architecture

**Framework: Routerino** (`routerino: 0.8.1`)

- **Single `NavigatorKey`** managed by `Routerino.navigatorKey`
- **`RouterinoHome`** wraps the home page with route handling
- Push-based navigation using `Routerino.context.push()` with fade transitions
- **`RouterinoTransition`** provides fade animations between pages
- No named routes; pages are pushed as widget builders
- Pages: `HomePage` (tabs: receive/send/settings), `SendPage`, `ProgressPage`, `ReceivePage`, `ReceiveOptionsPage`, `SelectedFilesPage`, `WebSendPage`, settings sub-pages, `DebugPage`, etc.
- Tab switching uses a `HomeTab` enum with a `homePageControllerProvider` managing the current tab

## 8. Networking Layer

The networking stack has **two parallel implementations**:

### A) Dart-based HTTP Server (Receive)
- Built on `dart:io` `HttpServer`
- Wrapped in a custom `SimpleServer` class with a minimal route system
- Routes installed by `ReceiveController` and `SendController` for protocol v2 endpoints
- Supports both HTTP and HTTPS (self-signed certificate)

### B) Rust-based HTTP Client (Send & Discovery)
- **`packages/core/src/http/client/`** — HTTP client built on `reqwest`
- Two client versions: `v2` (current) and `v3` (with nonce exchange + token signing)
- **`packages/core/src/http/server/`** — HTTP server built on `hyper` with optional TLS via `rustls`
- Used by the standalone `server/` binary and can be used by the Flutter app

### HTTP API Endpoints (v2):
| Method | Path | Purpose |
|--------|------|---------|
| POST | `/api/localsend/v2/register` | Device registration & discovery |
| GET | `/api/localsend/v2/info` | Get server info |
| POST | `/api/localsend/v2/prepare-upload` | Prepare file transfer session |
| POST | `/api/localsend/v2/upload` | Upload file binary |
| POST | `/api/localsend/v2/cancel` | Cancel a session |
| POST | `/api/localsend/v3/nonce` | Nonce exchange (v3) |
| POST | `/api/localsend/v3/register` | Authenticated register (v3) |

### Web Send:
- Web-based file sharing via http://device-ip:53317/
- WebSocket-like upload through the `/api/localsend/v2/prepare-download` and `/api/localsend/v2/download` endpoints
- Serves HTML/JS/i18n for the web interface

### Client Architecture:
- `RsHttpClient` (Rust) created in Dart via `createClient()` factory
- Two instances: `discovery` (short timeout) and `longLiving` (no timeout)
- Used by both the main isolate and child isolates (via cloning)
- Protocol: HTTP or HTTPS based on settings

## 9. Device Discovery Implementation

LocalSend uses a **hybrid discovery approach**:

### Primary: UDP Multicast (mDNS-like)
- Uses `RawDatagramSocket` bound to `0.0.0.0:53317`
- Joins multicast group `224.0.0.167` on all active network interfaces
- Devices broadcast a JSON payload (`MulticastDto`) containing: alias, version, device model, fingerprint, port, protocol
- Two flags: `announcement` (initial broadcast) and `announce` (response)
- Announcement sent at intervals (100ms, 500ms, 2000ms)
- TCP response is attempted first; UDP fallback if TCP fails
- Whitelist/blacklist filtering per network interface
- Runs in a **dedicated child isolate** (`multicastDiscoveryIsolate`) that streams discovered devices to the main isolate

### Secondary: HTTP/TCP Scan
- Used when multicast finds no devices (or forced via `forceLegacy`)
- Scans all 256 IPs in a `/24` subnet via HTTP `POST /api/localsend/v2/register`
- Runs with concurrency 50 (`TaskRunner`)
- Also supports scanning favorite devices (specific IP + port pairs)
- Runs in a **dedicated child isolate** (`httpScanDiscoveryIsolate`)

### Tertiary: WebRTC Signaling Discovery
- Connects to a public signaling server at `wss://public.localsend.org/v1/ws`
- Used for devices across different networks (NAT traversal)
- Managed by `signalingProvider`
- Devices register with the signaling server and receive `Join` events for peers in the same IP room
- WebRTC devices are tracked separately in state as `signalingDevices`

### Smart Scan Facade:
`StartSmartScan` coordinates all three methods:
1. Send multicast announcement immediately
2. Scan favorites in parallel
3. After 1s delay, if no devices found and still on send tab, start HTTP subnet scan

## 10. File Transfer Implementation

### Protocol:
1. **Prepare Upload** — Sender sends file metadata to receiver's `/api/localsend/v2/prepare-upload`
2. **Receiver Decision** — Receiver accepts/declines individual files, returns session ID + per-file tokens
3. **Upload** — Sender streams file binary to `/api/localsend/v2/upload?sessionId=X&fileId=Y&token=Z`
4. **Cancel** — Sender can cancel via `/api/localsend/v2/cancel`

### Upload Architecture:
- `SendNotifier` manages all active send sessions
- Creates `SendSessionState` per target device
- Uses **2 concurrent upload isolates** (`uploadIsolateCount = 2`)
- Files queued and sent in parallel (2 at a time)
- Each file upload runs in a child isolate, streaming progress back via `IsolateTaskStreamResult`
- Progress tracked in `ProgressNotifier` (ChangeNotifier for performance)

### Download (Receive) Architecture:
- Dart `HttpServer` handles incoming requests
- `ReceiveController` manages the receive flow:
  - Session management (single active session)
  - Pin validation (optional)
  - File acceptance/decline
  - File saving with destination directory support
  - Auto-finish, quick-save, save-to-gallery options
- Files saved using platform-specific file picker/saver

### WebRTC Transfer (Rust):
- WebRTC data channels for P2P transfer when direct HTTP connection fails
- SDP offer/answer exchange via signaling server
- File binary sent over `RTCDataChannel`
- Nonce-based authentication + PIN verification within the WebRTC channel
- Supports both sending and receiving

## 11. Encryption Implementation

### Certificate Infrastructure:
- **RSA 2048-bit** self-signed X.509 certificate generated on first app start
- Certificate subject: `CN=LocalSend User`
- Valid for 10 years (3650 days)
- Private key stored as PKCS#1 PEM in SharedPreferences
- Certificate hash (SHA-256) used as device **fingerprint** for identity
- mTLS (mutual TLS) prototype exists but is not enabled

### Token-Based Authentication (v3):
- **Ed25519 signing keys** generated per session
- Token format: `HASH_METHOD.BASE64_HASH.BASE64_SALT.SIGN_METHOD.BASE64_SIGNATURE`
- `sha256(publicKeyDer + salt)` signed with Ed25519
- Two modes:
  - **Timestamp-based**: salt = unix timestamp in seconds, valid for 1 hour (for device identity)
  - **Nonce-based**: salt = 32-byte random nonce (for session authentication)
- Verifying token validates: salt freshness, hash integrity, Ed25519 signature

### HTTPS:
- Self-signed certificate used for TLS encryption
- Dart's `HttpServer.bindSecure()` for receiving
- Rust's `rustls` for client connections
- Custom client certificate verifier extracts and validates peer certificates
- Trust-on-first-use (TOFU) model

### Pin Protection:
- Optional PIN for incoming transfers
- Max 3 attempts before lockout (per IP, tracked via `LruCache`)
- Pin validated on `prepare-upload` endpoint (returns 401)

### Hash:
- SHA-256 for certificate fingerprinting
- SHA-256 for file integrity (optional `sha256` field in `FileDto`)

## 12. Settings Architecture

### Storage:
- **`SharedPreferences`** on all platforms
- On Windows: uses a JSON file at `%APPDATA%\LocalSend\settings.json`
- **Portable mode**: on Linux/Windows/macOS, if a `settings.json` exists in the app directory, it uses `SharedPreferencesPortable`
- Legacy migration from old path `%APPDATA%\org.localsend\localsend_app\shared_preferences.json`

### Settings State:
- `PersistenceService` abstracts all read/write operations with key constants prefixed `ls_`
- `SettingsService` (NotifierProvider) loads from `PersistenceService` into a `SettingsState` immutable model
- Changes propagate to the isolate layer via `IsolateSyncSettingsAction`

### Settings Include:
- `alias`, `theme`/`colorMode`, `locale`, `port`
- `https` on/off
- `multicastGroup`, `networkWhitelist`, `networkBlacklist`, `discoveryTimeout`
- `destination` (download folder), `saveToGallery`, `saveToHistory`
- `quickSave`, `quickSaveFromFavorites`, `autoFinish`
- `receivePin`, `sendMode` (single/multiple)
- `minimizeToTray`, `saveWindowPlacement`, `enableAnimations`
- `deviceType`, `deviceModel`, `shareViaLinkAutoAccept`, `advancedSettings`
- `showToken` (for single-instance detection), `signalingServers`, `stunServers`

### Version Migration:
- Storage has a version number (`ls_version`); migrations run on version bumps
- Migrations in `persistence_provider_migrations.dart`

## 13. File Storage Architecture

### File Organization:
| Platform | Download Location |
|----------|-------------------|
| Android | `/storage/emulated/0/Download/LocalSend/` (via `ContentResolver` for gallery) |
| iOS | App documents directory, exposed via share sheet |
| Desktop | User-configurable via settings (`destination`), or `~/Downloads/LocalSend/` |
| Linux | `~/Downloads/LocalSend/` or XDG user dirs |

### File Handling:
- **`CrossFile`** — abstract file model supporting: file path, bytes, thumbnail, asset (XFile from image_picker)
- **`SendingFile`** — extends file with transfer state (status, token, progress)
- **Android content:// URIs** resolved via `UriContentStreamResolver` in the upload isolate
- **Gallery saving**: Android uses `MediaStore` via `gal` package; other platforms save to downloads
- **Receive history**: stored as `ReceiveHistoryEntry` list in SharedPreferences
- **Cache** cleared on app start (only if no share intent is pending)

### Platform-Specific File Operations:
- `file_picker` / `file_selector` for picking files
- `open_filex` / `open_dir` for opening files/folders after download
- `desktop_drop` for drag-and-drop on desktop
- `share_handler` for receiving share intents
- `image_picker` / `wechat_assets_picker` for media selection
- `path_provider` for standard directory access

## 14. Platform-Specific Code

Located in `app/lib/util/native/`:

| File | Platform | Purpose |
|------|----------|---------|
| `autostart_helper.dart` | Desktop | Launch at login (registry on Windows, plist on macOS, .desktop on Linux) |
| `tray_helper.dart` | Desktop | System tray icon (minimize/restore) |
| `context_menu_helper.dart` | Windows | Shell context menu integration |
| `taskbar_helper.dart` | Windows | Taskbar progress display |
| `cache_helper.dart` | All | Cache directory management |
| `cmd_helper.dart` | Windows | CLI argument handling |
| `content_uri_helper.dart` | Android | content:// URI to File descriptor conversion |
| `cross_file_converters.dart` | All | CrossFile conversion for share intents & CLIs |
| `device_info_helper.dart` | All | Platform-specific device info retrieval |
| `directories.dart` | All | Platform download directory resolution |
| `file_picker.dart` | All | File picker wrapper |
| `file_saver.dart` | All | File save dialogs |
| `ios_channel.dart` | iOS | iOS-specific method channels |
| `macos_channel.dart` | macOS | macOS-specific method channels |
| `open_file.dart` | All | Open files with system handler |
| `open_folder.dart` | All | Open folder in file manager |
| `pick_directory_path.dart` | Desktop | Directory picker dialog |
| `platform_check.dart` | All | Platform detection utilities |

Additional platform integrations:
- `bitsdojo_window` — custom window frame on desktop (move, resize)
- `window_manager` — window positioning/minimize/maximize
- `tray_manager` — system tray icon
- `wakelock_plus` — prevent screen sleep during transfers
- `windows_taskbar` — Windows taskbar progress indicator
- `flutter_displaymode` — high refresh rate on Android
- `yaru` — Ubuntu Yaru theme support
- `screen_retriever` / `system_settings_2` — desktop screen/settings
- `pasteboard` — clipboard access
- `flutter_rust_bridge` — Dart-Rust FFI bridge
- `device_apps` — list installed apps on Android (for APK picker)
- `connectivity_plus` / `network_info_plus` — network state

## 15. Important Packages

| Package | Purpose |
|---------|---------|
| `refena_flutter` | State management (primary architecture choice) |
| `routerino` | Navigation with fade transitions |
| `flutter_rust_bridge` | Dart-Rust FFI bridge for HTTP, WebRTC, crypto |
| `typed_isolates` (local) | Type-safe multi-isolate communication |
| `dart_mappable` | Code generation for serialization/immutability |
| `freezed_annotation` / `freezed` | Immutable data classes |
| `slang` / `slang_flutter` | i18n / localization (generated string files) |
| `shared_preferences` | Settings persistence |
| `basic_utils` / `convert` | X.509 certificate generation, crypto utilities |
| `uuid` | Session and file ID generation |
| `nanoid2` | Short unique IDs |
| `mime` | MIME type detection |
| `logging` | Structured logging |
| `flutter_markdown` | Changelog rendering |
| `dynamic_color` | Material You dynamic color support |
| `pretty_qr_code` | QR code generation for web send |
| `hyper` / `reqwest` / `tokio` / `rustls` (Rust) | HTTP server/client + TLS + async runtime |
| `webrtc` (Rust) | WebRTC for NAT traversal transfers |
| `ed25519-dalek` / `rsa` (Rust) | Cryptographic signing and verification |
| `axum` (standalone server) | Rust web framework for the headless server |
| `gal` | Gallery saving on Android |
| `in_app_purchase` | Donations (removed in FOSS builds) |

## 16. Potential Extension Points

### 1. Protocol v3 Full Adoption
- v3 nonce/token authentication already implemented in Rust core (`/api/localsend/v3/nonce`, `/api/localsend/v3/register`)
- Dart-side client already supports creating v3-compatible HTTP clients
- The Dart server (`server_provider.dart`) currently only implements v2 routes — v3 endpoints could be added to enable token-authenticated transfers

### 2. mTLS (Mutual TLS)
- Prototype code exists in `server_provider.dart` (commented out — lines 239-265)
- The Rust server already has a `CustomClientCertVerifier` that validates client certificates
- Full mTLS would allow peer identity verification without token exchange

### 3. WebRTC as Primary Transport
- Currently WebRTC is for NAT traversal fallback (via `public.localsend.org` signaling server)
- Could be promoted to primary transport for LAN as well (bypasses HTTP server on mobile where port binding is restricted)
- The Rust `webrtc` module already has a complete send/receive implementation with PIN and file streaming

### 4. Standalone Server Features
- The `server/` directory is a partially built headless server using `axum`
- Could be extended to: multi-user support, persistent file storage, cloud relay, authentication
- The Rust `packages/core` library already supports full server functionality via feature flags

### 5. Encrypted Relay / TURN Server
- The existing signaling server infrastructure could be extended with TURN relay
- Would enable direct file transfer without signaling for truly peer-to-peer connections through NAT

### 6. Additional Discovery Protocols
- Bluetooth LE discovery for offline-adjacent devices
- DNS-SD (Bonjour) discovery as an alternative to UDP multicast
- QR code scanning for out-of-network pairing (simple `WebSend` already exists)

### 7. Send Mode Extensions
- Current modes: `single` (one session at a time) and `multiple` (background concurrent)
- Could add: broadcast send (send to multiple devices), scheduled send, clipboard sync

### 8. Plugin System for File Processing
- The `CrossFile` model and `SendingFile` state provide hooks for pre/post processing
- Could add: image compression, video transcoding, document conversion before send

### 9. End-to-End Encryption
- Currently encryption is transport-layer (HTTPS) only
- Could add file-level encryption (AES-GCM) with key exchange via the token mechanism
- The Rust crypto module already has SHA-256 and key infrastructure

### 10. Sync / Cloud Features
- Persistence layer (`SharedPreferences`) could be swapped for a database (SQLite via `sqflite` or Rust-side)
- Device list, favorites, and receive history could sync across devices
- The `ServerState` and `SendSessionState` models are already designed for persistence
