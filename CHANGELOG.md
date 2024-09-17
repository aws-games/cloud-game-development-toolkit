<a name="unreleased"></a>
## [Unreleased]

### Bug Fixes
- changelog automation ([#261](https://github.com/aws-games/cloud-game-development-toolkit/issues/261))
- adding branch creation to workflow ([#259](https://github.com/aws-games/cloud-game-development-toolkit/issues/259))
- dependabot grouping terraform providers ([#228](https://github.com/aws-games/cloud-game-development-toolkit/issues/228))
- wait for cloud-init to complete prior to installing packages during Perforce Helix Core AMI creation ([#193](https://github.com/aws-games/cloud-game-development-toolkit/issues/193))
- **changelog:** GHA bot committer ([#255](https://github.com/aws-games/cloud-game-development-toolkit/issues/255))
- **changelog:** Add automated PR creation ([#252](https://github.com/aws-games/cloud-game-development-toolkit/issues/252))
- **fsx_automounter:** when FSx automounter can't list tags for an FSx volume, the AccessDenied exception is now treated as a warning ([#226](https://github.com/aws-games/cloud-game-development-toolkit/issues/226))
- **p4_configure:** resolve script execution errors and repair broken … ([#232](https://github.com/aws-games/cloud-game-development-toolkit/issues/232))

### Chore
- adjusting changelog automation to leverage GH api ([#266](https://github.com/aws-games/cloud-game-development-toolkit/issues/266))
- modify env var format for GH_TOKEN
- modify env var format for GH_TOKEN
- modify env var format for GH_TOKEN
- modify env var format for GH_TOKEN
- modify env var format for GH_TOKEN
- modify env var format for GH_TOKEN
- update changelog GHA
- add workflow logging
- **deps:** bump the aws-provider group across 5 directories with 1 update ([#231](https://github.com/aws-games/cloud-game-development-toolkit/issues/231))
- **deps:** bump hashicorp/awscc from 1.9.0 to 1.10.0 in /modules/perforce/helix-core ([#207](https://github.com/aws-games/cloud-game-development-toolkit/issues/207))
- **deps:** bump mkdocs-material from 9.5.33 to 9.5.34 in /docs ([#236](https://github.com/aws-games/cloud-game-development-toolkit/issues/236))
- **deps:** bump actions/upload-artifact from 4.3.6 to 4.4.0 ([#235](https://github.com/aws-games/cloud-game-development-toolkit/issues/235))
- **deps:** bump the aws-provider group across 5 directories with 1 update ([#241](https://github.com/aws-games/cloud-game-development-toolkit/issues/241))
- **deps:** bump the awscc-provider group across 3 directories with 1 update ([#242](https://github.com/aws-games/cloud-game-development-toolkit/issues/242))
- **deps:** bump the aws-provider group across 5 directories with 1 update ([#233](https://github.com/aws-games/cloud-game-development-toolkit/issues/233))
- **deps:** bump mkdocs-open-in-new-tab from 1.0.3 to 1.0.5 in /docs ([#263](https://github.com/aws-games/cloud-game-development-toolkit/issues/263))
- **deps:** bump mkdocs-material from 9.5.32 to 9.5.33 in /docs ([#229](https://github.com/aws-games/cloud-game-development-toolkit/issues/229))
- **deps:** bump hashicorp/awscc from 1.10.0 to 1.11.0 in /samples/simple-build-pipeline ([#220](https://github.com/aws-games/cloud-game-development-toolkit/issues/220))
- **deps:** bump mkdocs-material from 9.5.31 to 9.5.32 in /docs ([#211](https://github.com/aws-games/cloud-game-development-toolkit/issues/211))
- **deps:** bump python from 3.12 to 3.12.6 in /docs ([#243](https://github.com/aws-games/cloud-game-development-toolkit/issues/243))
- **deps:** bump hashicorp/awscc from 1.9.0 to 1.10.0 in /modules/perforce/helix-authentication-service ([#205](https://github.com/aws-games/cloud-game-development-toolkit/issues/205))
- **deps:** bump hashicorp/aws from 5.62.0 to 5.63.1 in /samples/simple-build-pipeline ([#216](https://github.com/aws-games/cloud-game-development-toolkit/issues/216))
- **deps:** bump hashicorp/awscc from 1.6.0 to 1.9.0 in /modules/perforce/helix-authentication-service ([#196](https://github.com/aws-games/cloud-game-development-toolkit/issues/196))
- **deps:** bump hashicorp/aws from 5.59.0 to 5.62.0 in /modules/perforce/helix-authentication-service ([#197](https://github.com/aws-games/cloud-game-development-toolkit/issues/197))
- **deps:** bump hashicorp/awscc from 1.6.0 to 1.9.0 in /modules/perforce/helix-core ([#198](https://github.com/aws-games/cloud-game-development-toolkit/issues/198))
- **deps:** bump hashicorp/aws from 5.59.0 to 5.62.0 in /modules/perforce/helix-core ([#199](https://github.com/aws-games/cloud-game-development-toolkit/issues/199))
- **deps:** bump hashicorp/aws from 5.59.0 to 5.62.0 in /modules/perforce/helix-swarm ([#200](https://github.com/aws-games/cloud-game-development-toolkit/issues/200))
- **deps:** bump hashicorp/aws from 5.59.0 to 5.62.0 in /samples/simple-build-pipeline ([#201](https://github.com/aws-games/cloud-game-development-toolkit/issues/201))
- **deps:** bump hashicorp/awscc from 1.6.0 to 1.9.0 in /samples/simple-build-pipeline ([#202](https://github.com/aws-games/cloud-game-development-toolkit/issues/202))
- **deps:** bump mike from 2.1.2 to 2.1.3 in /docs ([#189](https://github.com/aws-games/cloud-game-development-toolkit/issues/189))
- **deps:** bump hashicorp/aws from 5.59.0 to 5.62.0 in /modules/jenkins ([#195](https://github.com/aws-games/cloud-game-development-toolkit/issues/195))

### Docs
- add openssf scorecard badge to readme ([#219](https://github.com/aws-games/cloud-game-development-toolkit/issues/219))
- link to installation instructions for required tools, fix packer command invocation instructions ([#194](https://github.com/aws-games/cloud-game-development-toolkit/issues/194))
- Windows Build AMI README ([#187](https://github.com/aws-games/cloud-game-development-toolkit/issues/187))


<a name="v1.0.0-alpha"></a>
## [v1.0.0-alpha] - 2024-08-07

<a name="staging"></a>
## [staging] - 2024-08-07

<a name="latest"></a>
## latest - 2024-08-07
### Bug Fixes
- fix issue where SSH public key was not baked into the Windows Jenkins build agent AMI ([#150](https://github.com/aws-games/cloud-game-development-toolkit/issues/150))
- bug fixes for FSxZ storage in build farm ([#152](https://github.com/aws-games/cloud-game-development-toolkit/issues/152))
- allow Jenkins build agents to discover FSx volumes/snapshots and make outbound Internet connections ([#147](https://github.com/aws-games/cloud-game-development-toolkit/issues/147))

### Chore
- add CODEOWNERS file ([#132](https://github.com/aws-games/cloud-game-development-toolkit/issues/132))
- Updates to docs ([#63](https://github.com/aws-games/cloud-game-development-toolkit/issues/63))
- fix makefile ([#65](https://github.com/aws-games/cloud-game-development-toolkit/issues/65))
- Modify version handling in Docs ([#66](https://github.com/aws-games/cloud-game-development-toolkit/issues/66))
- **deps:** bump mkdocs-material from 9.5.27 to 9.5.28 in /docs ([#135](https://github.com/aws-games/cloud-game-development-toolkit/issues/135))
- **deps:** bump mkdocs-material from 9.5.26 to 9.5.27 in /docs ([#77](https://github.com/aws-games/cloud-game-development-toolkit/issues/77))
- **deps:** bump aquasecurity/trivy-action from 0.23.0 to 0.24.0 ([#137](https://github.com/aws-games/cloud-game-development-toolkit/issues/137))
- **deps:** bump actions/upload-artifact from 4.3.3 to 4.3.4 ([#136](https://github.com/aws-games/cloud-game-development-toolkit/issues/136))
- **deps:** bump actions/upload-artifact from 4.3.5 to 4.3.6 ([#178](https://github.com/aws-games/cloud-game-development-toolkit/issues/178))
- **deps:** bump mkdocs-material from 9.5.29 to 9.5.30 in /docs ([#153](https://github.com/aws-games/cloud-game-development-toolkit/issues/153))
- **deps:** bump mike from 2.1.1 to 2.1.2 in /docs ([#110](https://github.com/aws-games/cloud-game-development-toolkit/issues/110))
- **deps:** bump mkdocs-material from 9.5.28 to 9.5.29 in /docs ([#144](https://github.com/aws-games/cloud-game-development-toolkit/issues/144))
- **deps:** bump github/codeql-action from 3.25.8 to 3.25.10 ([#69](https://github.com/aws-games/cloud-game-development-toolkit/issues/69))
- **deps:** bump ossf/scorecard-action from 2.3.3 to 2.4.0 ([#167](https://github.com/aws-games/cloud-game-development-toolkit/issues/167))
- **deps:** bump actions/upload-artifact from 4.3.4 to 4.3.5 ([#171](https://github.com/aws-games/cloud-game-development-toolkit/issues/171))
- **deps:** bump mkdocs-material from 9.5.30 to 9.5.31 in /docs ([#172](https://github.com/aws-games/cloud-game-development-toolkit/issues/172))
- **deps:** bump github/codeql-action from 3.24.9 to 3.25.8 ([#53](https://github.com/aws-games/cloud-game-development-toolkit/issues/53))
- **deps:** bump mkdocs-material from 9.5.25 to 9.5.26 in /docs ([#54](https://github.com/aws-games/cloud-game-development-toolkit/issues/54))

### Code Refactoring
- Perforce Helix Core AMI revamp, simple build pipeline DNS ([#73](https://github.com/aws-games/cloud-game-development-toolkit/issues/73))

### Docs
- update changelog ([#181](https://github.com/aws-games/cloud-game-development-toolkit/issues/181))
- update main docs page ([#179](https://github.com/aws-games/cloud-game-development-toolkit/issues/179))
- update layout of documentation main page theme ([#175](https://github.com/aws-games/cloud-game-development-toolkit/issues/175))
- update documentation ([#163](https://github.com/aws-games/cloud-game-development-toolkit/issues/163))
- update workflow for docs ([#129](https://github.com/aws-games/cloud-game-development-toolkit/issues/129))
- update workflow ([#128](https://github.com/aws-games/cloud-game-development-toolkit/issues/128))
- fix workflow to use gh inputs from workflow ([#127](https://github.com/aws-games/cloud-game-development-toolkit/issues/127))
- update to docs and flip release workflow to manual ([#126](https://github.com/aws-games/cloud-game-development-toolkit/issues/126))
- fix commit depth ([#125](https://github.com/aws-games/cloud-game-development-toolkit/issues/125))
- modify the workflow for docs release and update documentation ([#124](https://github.com/aws-games/cloud-game-development-toolkit/issues/124))
- fix docs ci ([#123](https://github.com/aws-games/cloud-game-development-toolkit/issues/123))
- modify git fetch-depth for docs ci ([#121](https://github.com/aws-games/cloud-game-development-toolkit/issues/121))
- update README.md ([#119](https://github.com/aws-games/cloud-game-development-toolkit/issues/119))
- consolidate Ansible playbooks under assets ([#117](https://github.com/aws-games/cloud-game-development-toolkit/issues/117))
- fix url to documentation to point to /latest ([#80](https://github.com/aws-games/cloud-game-development-toolkit/issues/80))
- add GH Pull Request template ([#67](https://github.com/aws-games/cloud-game-development-toolkit/issues/67))
- updates workflow and adds changelog automation ([#61](https://github.com/aws-games/cloud-game-development-toolkit/issues/61))
- add issue template for RFCs ([#57](https://github.com/aws-games/cloud-game-development-toolkit/issues/57))
- add git-chglog for changelog generation ([#49](https://github.com/aws-games/cloud-game-development-toolkit/issues/49))
- enable workflow dispatch ([#36](https://github.com/aws-games/cloud-game-development-toolkit/issues/36))
- fix docs release workflow ([#34](https://github.com/aws-games/cloud-game-development-toolkit/issues/34))
- convert docs releases to use mike ([#33](https://github.com/aws-games/cloud-game-development-toolkit/issues/33))
- adds markdown docs for assets, modules, playbooks, and samples ([#32](https://github.com/aws-games/cloud-game-development-toolkit/issues/32))
- adds issue template for submitting maintenance issues ([#31](https://github.com/aws-games/cloud-game-development-toolkit/issues/31))
- Adds documentation and GH workflow for build/publish of docs ([#21](https://github.com/aws-games/cloud-game-development-toolkit/issues/21))
- Updates to project README ([#20](https://github.com/aws-games/cloud-game-development-toolkit/issues/20))
- Adds project docs ([#13](https://github.com/aws-games/cloud-game-development-toolkit/issues/13))

### Features
- Added getting-started documentation for quickstart with Simple Build Pipeline ([#177](https://github.com/aws-games/cloud-game-development-toolkit/issues/177))
- Updates to CI configurations for pre-commit and GHA ([#154](https://github.com/aws-games/cloud-game-development-toolkit/issues/154))
- Helix Authentication Extension ([#82](https://github.com/aws-games/cloud-game-development-toolkit/issues/82))
- enable web based administration through variables for HAS ([#79](https://github.com/aws-games/cloud-game-development-toolkit/issues/79))
- complete sample with both Jenkins and Perforce modules ([#60](https://github.com/aws-games/cloud-game-development-toolkit/issues/60))
- Add packer build agent templates for Linux (Ubuntu Jammy 22.04, Amazon Linux 2023) ([#46](https://github.com/aws-games/cloud-game-development-toolkit/issues/46))
- **devops:** Add new DevOps playbook files ([#76](https://github.com/aws-games/cloud-game-development-toolkit/issues/76))
- **packer:** switch AMI from Rocky Linux to Amazon Linux 2023 and up… ([#141](https://github.com/aws-games/cloud-game-development-toolkit/issues/141))


[Unreleased]: https://github.com/aws-games/cloud-game-development-toolkit/compare/v1.0.0-alpha...HEAD
[v1.0.0-alpha]: https://github.com/aws-games/cloud-game-development-toolkit/compare/staging...v1.0.0-alpha
[staging]: https://github.com/aws-games/cloud-game-development-toolkit/compare/latest...staging
