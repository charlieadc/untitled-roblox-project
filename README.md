# untitled-roblox-project

Luau lives under `src`. [AGENTS.md](AGENTS.md) has the edit workflow, the folder map, and the file names.

## Install Rokit

On macOS or Linux, run:

```sh
curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/v1.2.0/scripts/install.sh | bash
```

On Windows, open PowerShell and run:

```powershell
Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/v1.2.0/scripts/install.ps1 | Invoke-Expression
```

Open a new terminal so `rokit` is on `PATH`.

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
