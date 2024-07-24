# Jenkins example pipelines

This folder contains example Jenkins pipelines for building various pieces of software. To use them, [create a new Jenkins pipeline project](https://www.jenkins.io/doc/book/pipeline/getting-started/#through-the-classic-ui), and then copy-and-paste the contents of a sample file into the "Pipeline" section in the configuration page.

You will likely need to change the pipelines slightly to suit your needs, for example to alter the agent node labels on which steps run. Many pipelines also depend on a global Jenkins environment variable to be set: `FSX_WORKSPACE_VOLUME_ID`, which should be set to the FSx for OpenZFS volume ID of the Workspace volume.

The pipelines are primarily written as [Declarative Pipelines](https://www.jenkins.io/doc/book/pipeline/syntax/), with sections of [scripted pipeline blocks](https://www.jenkins.io/doc/book/pipeline/syntax/#script) used to pass variables between stages or to implement try/catch behavior.

## `ue5_build_pipeline.groovy`

This pipeline builds Unreal Engine 5 on Linux from its Git repository on GitHub, using an FSx volume as workspace cache and another FSx volume to (optionally) store build cache artifacts to speed up subsequent builds.

> **_Note:_** this pipeline requires that you configure GitHub credentials in Jenkins. You also need to [get access to the Unreal Engine 5 source code](https://www.unrealengine.com/en-US/ue-on-github).

> **_Note:_** although this pipeline supports [octobuild](https://github.com/octobuild/octobuild) for caching build artifacts out-of-the-box, octobuild for Linux requires a patch to the Unreal Engine 5 source code. We recommend forking Unreal Engine 5, applying the necessary patch to your fork, and then building from your own fork instead of from the upstream repository. Please refer to the octobuild readme for instructions on which patches to apply.

> **_Note:_** you will need to run this on a build node with large /tmp space.

The pipeline is divided in two stages:
1. **Prepare** - Clones or pulls the Git repository to the FSx workspace volume, then creates an FSx snapshot and waits for it to be available. This stage is skipped if the `source_path` parameter is provided.
2. **Build** - Builds Unreal Engine 5 from the snapshot location on x86_64 Linux. Because FSx for OpenZFS snapshots are read-only, on Linux a temporary [overlay file system](https://en.wikipedia.org/wiki/OverlayFS) is created.

## `godot.groovy`

This pipeline builds the Godot engine from its public Git repository, using an FSx volume as workspace cache and another FSx volume to store _sccache_ artifacts to speed up subsequent builds.

The pipeline is divided in two stages:
1. **Prepare** - Clones or pulls the Git repository to the FSx workspace volume, then creates an FSx snapshot and waits for it to be available. This stage is skipped if the `source_path` parameter is provided.
2. **Build** - Builds Godot from the snapshot location on x86_64 Linux and arm64 Linux. Because FSx for OpenZFS snapshots are read-only, and Godot does not build from a read-only filesystem, on Linux a temporary [overlay file system](https://en.wikipedia.org/wiki/OverlayFS) is created.

## `gamelift_sdk.groovy`

This pipeline builds the [GameLift Server C++ SDK](https://aws.amazon.com/gamelift/getting-started-sdks/) in 8 different configurations. It uses an FSx volume as workspace cache and (optionally) another FSx volume to store _sccache_ artifacts to speed up subsequent builds.

The build configurations are:
|Operating sytem | CPU architecture | Build configuration |
|---|---|---|
|Ubuntu Jammy 22.04 | x86_64 | Standard build          |
|Ubuntu Jammy 22.04 | x86_64 | Built for Unreal Engine |
|Ubuntu Jammy 22.04 | arm64  | Standard build          |
|Ubuntu Jammy 22.04 | arm64  | Built for Unreal Engine |
|Amazon Linux 2023  | x86_64 | Standard build          |
|Amazon Linux 2023  | x86_64 | Built for Unreal Engine |
|Amazon Linux 2023  | arm64  | Standard build          |
|Amazon Linux 2023  | arm64  | Built for Unreal Engine |

> **_Note:_** you will most likely not need each of these build configurations to compile the GameLift Server SDK for your game. We recommend that you delete those you don't need from the pipeline manually.

The pipeline is divided in two stages:
1. **Prepare** - Downloads the GameLift Server SDK .zip to the FSx workspace volume, then creates an FSx snapshot and waits for it to be available. This stage is skipped if the `source_path` parameter is provided.
2. **Build** - Builds the SDK from the snapshot location on aforementioned operating systems and configurations.

## `delete_oldest_snapshot.groovy`

This parameterized pipeline deletes the oldest FSx snapshot that's older than 7 days. Use this to clean up automatically-created snapshots for workspace volumes that you no longer need.

This pipeline has the following input parameters:
* `FSX_VOLUME_ID` - FSx volume ID of the volume to delete the oldest snapshot from.

> **_Note:_** this pipeline performs no logic to check whether a snapshot was created automatically, so do not run this pipeline against FSx volumes where you use snapshots for data backup purposes.

## `multiplatform_build.groovy`

This simple multi-stage pipeline demonstrates how to build for multiple platforms by running multiple stages, and how to paralellize steps in a single stage across different build nodes. It can be used to verify that build nodes for various platforms work correctly, and is a great starting point for creating new pipelines.
