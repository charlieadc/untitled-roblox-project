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

Put the kit Tool in Workspace. Leave that Tool there. The prep clones it.

`src/shared/Guns` becomes `ReplicatedStorage.Guns`, and each file there is a config ModuleScript. Prepped models go to `ReplicatedStorage.GunModels`. A model and a module of the same gun name then live in different folders.

Run `tools/studio/PrepKitGun.luau` in Studio and call the function it returns. Pass the Tool name. The current kit Tool is M13.

```lua
prepKitGun("M13")
```

The function does seven things.

1. Clone the Tool. The original stays in Workspace.
2. Make a Model of the same name and move the clone's BaseParts into it.
3. Delete scripts, remote events, and remote functions. Delete anything else that did not move with a part. Sounds, particle emitters, and lights that are parented to parts stay.
4. Set PrimaryPart to Grip.
5. Set every part unanchored, with CanCollide, CanQuery, and CanTouch off, and Massless true.
6. Give Mag and Bolt a Motor6D of the same name. Part0 is Grip, and C0 keeps the current offset. Every other part gets a WeldConstraint to Grip.
7. Parent the model under ReplicatedStorage.GunModels. If that name is already there, replace it.

The printout is the sound count and the particle emitter count, Tool then model. Those counts match when the prep kept the effects that live on the parts.

If `src/shared/Guns/<Name>.luau` does not exist, add it and set `Model` to `<Name>`. Push the module from disk. Do not hand-edit it in Studio.

## Viewmodel contracts

`ReplicatedStorage.GunModels.<Name>` is a Model.

- Grip is the PrimaryPart. Joints use Grip as Part0.
- AimPart is the sight. FirePart is the muzzle.
- Mag and Bolt each have a Motor6D of the same name.
- Chamber is optional.
- The model has no scripts.
- Forward is `(FirePart.Position - AimPart.Position).Unit`. The pivot is not forward.

`ReplicatedStorage.Viewmodels.Arms` is one Model for every gun. Build it in Studio.

- PrimaryPart is HumanoidRootPart. It is anchored, CanCollide is off, and Transparency is 1. The camera sits on it.
- LeftArm and RightArm are unanchored. CanCollide, CanQuery, and CanTouch are off.
- HumanoidRootPart contains the Motor6Ds named LeftArm and RightArm.
- RightArm has an Attachment named GripAttachment.
- An AnimationController contains an Animator.

`ViewmodelRig.build` clones the arms and the model named by `GunConfig.get(gunName).Model`. It parents the gun model under the arms and adds a Motor6D named Grip on RightArm. Part0 is RightArm. Part1 is the gun Grip. C0 is `GripAttachment.CFrame`. C1 is a rotation that points the derived barrel along the arm's -Z.

A missing arms model, gun model, or named part becomes a block with that name. `build` warns once. `ViewmodelRig.validate` checks both contracts. `ViewmodelRig.sightCFrame` returns `CFrame.lookAt` from AimPart toward FirePart, with the Grip up vector.
