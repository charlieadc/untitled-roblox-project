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

## Add a gun

Leave the kit Tool in Workspace. Run `tools/studio/PrepKitGun.luau` with the Tool name. The current tool is M13.

```lua
prepKitGun("M13")
```

The model is written to `ReplicatedStorage.GunModels`. Config modules stay in `ReplicatedStorage.Guns`. Rerunning replaces the model of that name.

`Viewmodels.Arms` is the shared rig. Its PrimaryPart is the anchored invisible `HumanoidRootPart`, with `Left Arm` and `Right Arm` motors, a `Grip` motor on the right arm, and an Animator. On the gun, Grip is the PrimaryPart, AimPart and FirePart define forward, and Mag and Bolt are motors on Grip. `ViewmodelRig.build` joins them and warns once when it has to fill a missing model or part.
