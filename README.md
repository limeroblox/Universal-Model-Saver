# Universal Model Saver

A professional Lua-based tool for model decomposition and preservation across multiple Roblox project workflows. The system supports modular export formats and flexible deployment configurations.

## Features

### Export Types
- **Standard Export** – Decomposes models and saves them as RBXM/RBXMx files to local storage
- **Webhook Integration** (Experimental) – Uploads exports to designated webhooks using URL identifiers
- **Validation Testing** – Decomposes the local player's avatar to verify core functionality

## Configuration

### Decompilation Settings
- **Script Preservation** – Extracts LocalScripts and ModuleScripts only
- **Security Filtering** – Basic Script objects are excluded from export for compliance with platform policies

### Operational Modes
- **Standard Mode** – General-purpose model preservation
- **Nightbound Mode** – Specialized export for Nightbound entities with compatibility for Blackout Revival Zombies gameplay systems

## Technical Specifications
- **Language**: Lua 5.1+ with JSON serialization support
- **Output Formats**: RBXM, RBXMx
- **Dependencies**: Roblox Studio API, HTTP services for webhook functionality

## Compatibility Notice
Webhook functionality requires proper URL configuration and network permissions. Experimental features may require additional security review for production deployment.

## Acknowledgments
Architectural inspiration from [Universal Syn Saveinstance](https://github.com/luau/UniversalSynSaveInstance)

---

*For implementation details and contribution guidelines, refer to the source repository documentation.*
