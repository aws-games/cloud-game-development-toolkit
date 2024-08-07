<a name="unreleased"></a>
## [Unreleased]

### Ci
- update changelog GHA permissions ([#180](https://github.com/aws-games/cloud-game-development-toolkit/issues/180))


<a name="v1.0.0-alpha"></a>
## [v1.0.0-alpha] - 2024-08-07

<a name="latest"></a>
## latest - 2024-08-07
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

### Ci
- fix gha workflow level permissions to contents: read ([#170](https://github.com/aws-games/cloud-game-development-toolkit/issues/170))
- update dependabot terraform versioning ([#162](https://github.com/aws-games/cloud-game-development-toolkit/issues/162))
- remove packer github actions which are moving to codebuild in CI ([#164](https://github.com/aws-games/cloud-game-development-toolkit/issues/164))
- add config scanning to trivy ([#143](https://github.com/aws-games/cloud-game-development-toolkit/issues/143))
- add checkov ([#140](https://github.com/aws-games/cloud-game-development-toolkit/issues/140))
- fix workflow permissions ([#139](https://github.com/aws-games/cloud-game-development-toolkit/issues/139))
- consolidate security workflows under a reusable workflow template… ([#138](https://github.com/aws-games/cloud-game-development-toolkit/issues/138))
- add trivy scan github action ([#134](https://github.com/aws-games/cloud-game-development-toolkit/issues/134))
- add pre-commit hooks ([#133](https://github.com/aws-games/cloud-game-development-toolkit/issues/133))
- adds codeql github action ([#131](https://github.com/aws-games/cloud-game-development-toolkit/issues/131))
- update packer ci matrix to run to completion even with errors ([#130](https://github.com/aws-games/cloud-game-development-toolkit/issues/130))
- modify the run if statement for the workflow ([#115](https://github.com/aws-games/cloud-game-development-toolkit/issues/115))
- fix permissions ([#89](https://github.com/aws-games/cloud-game-development-toolkit/issues/89))
- fix permissions on Packer ci ([#88](https://github.com/aws-games/cloud-game-development-toolkit/issues/88))
- add packer template ci ([#87](https://github.com/aws-games/cloud-game-development-toolkit/issues/87))
- packer build agent linux updates ([#70](https://github.com/aws-games/cloud-game-development-toolkit/issues/70))
- add release-drafter github action ([#58](https://github.com/aws-games/cloud-game-development-toolkit/issues/58))
- adds dependabot.yml ([#52](https://github.com/aws-games/cloud-game-development-toolkit/issues/52))
- updates to release workflow ([#50](https://github.com/aws-games/cloud-game-development-toolkit/issues/50))
- update docs release workflow ([#48](https://github.com/aws-games/cloud-game-development-toolkit/issues/48))
- add docs release versioning ([#47](https://github.com/aws-games/cloud-game-development-toolkit/issues/47))
- Update github action for docs ([#39](https://github.com/aws-games/cloud-game-development-toolkit/issues/39))
- fix docs release automation ([#37](https://github.com/aws-games/cloud-game-development-toolkit/issues/37))
- modify Makefile ([#35](https://github.com/aws-games/cloud-game-development-toolkit/issues/35))
- resolving merge conflicts ([#30](https://github.com/aws-games/cloud-game-development-toolkit/issues/30))
- fix permissions on gh action ([#29](https://github.com/aws-games/cloud-game-development-toolkit/issues/29))
- bump versions in ossf scorecard action ([#27](https://github.com/aws-games/cloud-game-development-toolkit/issues/27))
- update ossf scorecard action to trigger on pull requests on main ([#26](https://github.com/aws-games/cloud-game-development-toolkit/issues/26))
- setup ossf scorecard GH action ([#23](https://github.com/aws-games/cloud-game-development-toolkit/issues/23))
- Updates documentation release workflow, adds semantic.yml and release-drafter.yml  ([#22](https://github.com/aws-games/cloud-game-development-toolkit/issues/22))

### Docs
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

### Feat
- Added getting-started documentation for quickstart with Simple Build Pipeline ([#177](https://github.com/aws-games/cloud-game-development-toolkit/issues/177))
- Updates to CI configurations for pre-commit and GHA ([#154](https://github.com/aws-games/cloud-game-development-toolkit/issues/154))
- Helix Authentication Extension ([#82](https://github.com/aws-games/cloud-game-development-toolkit/issues/82))
- enable web based administration through variables for HAS ([#79](https://github.com/aws-games/cloud-game-development-toolkit/issues/79))
- complete sample with both Jenkins and Perforce modules ([#60](https://github.com/aws-games/cloud-game-development-toolkit/issues/60))
- Add packer build agent templates for Linux (Ubuntu Jammy 22.04, Amazon Linux 2023) ([#46](https://github.com/aws-games/cloud-game-development-toolkit/issues/46))
- **devops:** Add new DevOps playbook files ([#76](https://github.com/aws-games/cloud-game-development-toolkit/issues/76))
- **packer:** switch AMI from Rocky Linux to Amazon Linux 2023 and up… ([#141](https://github.com/aws-games/cloud-game-development-toolkit/issues/141))

### Fix
- fix issue where SSH public key was not baked into the Windows Jenkins build agent AMI ([#150](https://github.com/aws-games/cloud-game-development-toolkit/issues/150))
- bug fixes for FSxZ storage in build farm ([#152](https://github.com/aws-games/cloud-game-development-toolkit/issues/152))
- allow Jenkins build agents to discover FSx volumes/snapshots and make outbound Internet connections ([#147](https://github.com/aws-games/cloud-game-development-toolkit/issues/147))

### Refactor
- Perforce Helix Core AMI revamp, simple build pipeline DNS ([#73](https://github.com/aws-games/cloud-game-development-toolkit/issues/73))


[Unreleased]: https://github.com/aws-games/cloud-game-development-toolkit/compare/v1.0.0-alpha...HEAD
[v1.0.0-alpha]: https://github.com/aws-games/cloud-game-development-toolkit/compare/latest...v1.0.0-alpha
