# Agents

Write all code on disk under `src`.

Edit Luau on disk under `src`. Then push the script into Studio with Studio MCP. Never hand-edit a script in Studio. Disk is the source of truth.

Map each folder to a service.

- `src/server` maps to ServerScriptService.
- `src/client` maps to `StarterPlayer.StarterPlayerScripts`.
- `src/shared` maps to ReplicatedStorage.
- A subfolder becomes a Folder.

Name each file for its class.

- `Name.server.luau` is a Script.
- `Name.client.luau` is a LocalScript.
- `Name.luau` is a ModuleScript.

The instance name is the file name without suffixes.

From the repository root, run these commands before each pull request.

```sh
selene src
stylua --check src
```
