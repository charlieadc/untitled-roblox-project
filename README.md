# untitled-roblox-project

Luau lives under `src`. Rojo syncs those files into Roblox Studio.

## Install Rokit

On macOS or Linux, run:

```sh
curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
```

On Windows, open PowerShell and run:

```powershell
Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression
```

Open a new terminal so `rokit` is on `PATH`.

## Install the pinned tools

From the repository root, run:

```sh
rokit install
```

Rokit asks you to trust `rojo-rbx/rojo`, `Kampfkarren/selene`, `JohnnyMorganz/stylua`, and `JohnnyMorganz/luau-lsp`. Trust them. The versions are the lines in `rokit.toml`. Rojo stays on 7.6.1. Rojo 7.7.0 stops detecting new files after `rojo serve` starts. The open report is [rojo-rbx/rojo#1300](https://github.com/rojo-rbx/rojo/issues/1300).

## Install the Studio plugin

The plugin and the CLI have to be the same build. A mismatch is the main thing that breaks sync.

On the computer where Studio is installed, run:

```sh
rojo plugin install
```

That command writes the plugin packed inside the Rojo 7.6.1 CLI. In Studio, the Rojo version must say 7.6.1. If it shows another version, remove that plugin and run `rojo plugin install` again.

On Linux, `rojo plugin install` exits with `Your platform is not currently supported`. Run it on Windows or macOS.

## Serve the place

From the repository root, run:

```sh
rojo serve
```

The server listens on `localhost` port `34872`. Connect the plugin to that server. Studio must be in Edit mode. Stop the playtest before you sync again.

If a second `rojo serve` exits with `Address already in use`, the first server is still running. Use that one.

To write a place file instead, run:

```sh
rojo build -o test.rbxl
```

Git ignores `test.rbxl`.

## Turn on Studio MCP

In Studio, open **Assistant**, then **Manage MCP Servers**, then **Enable Studio as MCP server**. Then choose **Quick connect** for your AI client.

Read `AGENTS.md` before you edit scripts.

## Check before a pull request

From the repository root, run:

```sh
selene src
stylua --check src
```

Both commands exit 0. CI runs the same two commands on pull requests.
