# Agents

Write all code on disk under `src`.

Use Studio MCP only for the map, for instances, for playtests, and for the console. Never edit a Rojo-managed script inside Studio.

Rojo syncs only in Edit mode. Stop the playtest before you sync again.

`default.project.json` maps directories to services.

- `src/server` syncs into ServerScriptService.
- `src/client` syncs into `StarterPlayer.StarterPlayerScripts`.
- `src/shared` syncs into ReplicatedStorage.

Name server scripts `Name.server.luau`, client scripts `Name.client.luau`, and shared modules `Name.luau`. Do not put `init.server.luau`, `init.client.luau`, or `init.luau` directly in those three directories. Rojo would try to turn the service into a script.

Rojo removes a child of those three services when no file represents that child. Put the map in Workspace. The project file does not list Workspace.

From the repository root, run these commands before each pull request.

```sh
selene src
stylua --check src
```
