# untitled-roblox-project

Luau lives under `src`. Edit it on disk, then push the script into Studio with Studio MCP. Never hand-edit a script in Studio. Disk is the source of truth.

## Map each folder to a service

- `src/server` maps to ServerScriptService.
- `src/client` maps to `StarterPlayer.StarterPlayerScripts`.
- `src/shared` maps to ReplicatedStorage.
- A subfolder becomes a Folder.

## Name each file for its class

- `Name.server.luau` is a Script.
- `Name.client.luau` is a LocalScript.
- `Name.luau` is a ModuleScript.

The instance name is the file name without suffixes.

## Install Rokit

Install Rokit 1.2.0. Open a new terminal so `rokit` is on `PATH`.

## Install the pinned tools

From the repository root, run:

```sh
rokit install
```

Rokit asks you to trust `Kampfkarren/selene` and `JohnnyMorganz/stylua`. Trust them. The versions are the lines in `rokit.toml`.

## Check before a pull request

From the repository root, run:

```sh
selene src
stylua --check src
```

## Turn on Studio MCP

In Studio, open **Assistant**, then **Manage MCP Servers**, then **Enable Studio as MCP server**. Then choose **Quick connect** for your AI client.
