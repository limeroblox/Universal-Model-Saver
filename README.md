# Universal Model Saver

> [!WARNING]
> This Project is In Development, Expect Bugs and Issues When Using This Tool                                                            
> Reccomended To Use This Tool With A Alternative Account

A Lua-powered instrument for model dissection and conservation during the workflow of various Roblox projects. It comes with different types of exports and has the configurations for the deployment to be as flexible as required.

## Features

### Export Types
- **Standard Export** – Breaks down the models and saves them as RBXM/RBXMx files in the local storage (Workspace/Universal-Model-Saver/Model.rbxm or rbxmx).
- **Webhook Integration** (Experimental) – Sends uploads to webhooks with the help of designated URL identifiers (e.g., Discord Webhooks).
- **Validation Testing** – Takes apart the local player's avatar to check the fundamental operation and deletes the file just after to avoid space wastage.

## Configuration

### Decompilation Settings
- **Script Preservation** – Only LocalScripts and ModuleScripts are extracted
- **Security Filtering** – Basic Script objects are not included in the export as they are considered not complying with the platform's policies

### Operational Modes
- **Standard Mode** – The model preservation is done for general use.
- **Nightbound Mode** – It is a specialized export for Nightbound entities that is compatible with the Blackout Revival Zombies gameplay systems.

## Technical Specifications
- **Language**: Lua 5.1+ with support for JSON serialization
- **Output Formats**: RBXM, RBXMx
- **Dependencies**: Roblox Exploit & Studio API, HTTP services for webhook functionality

## Compatibility Notice
The URL must be correctly configured and the network permissions granted for the webhook functionality. Also, experimental features might need to go through a security review before being deployed in a production environment.

## Acknowledgments
Architectural inspiration from [Universal Syn Saveinstance](https://github.com/luau/UniversalSynSaveInstance)
---

*For implementation details and contribution guidelines, please refer to the source repository documentation.*
