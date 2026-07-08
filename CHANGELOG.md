<a name="unreleased"></a>
## [Unreleased]


<a name="v1.1.6"></a>
## [v1.1.6] - 2026-07-02
### Bug Fixes
- resolve warning about iam policy type deprecation
- link updates for documentation ([#841](https://github.com/aws-games/cloud-game-development-toolkit/issues/841))
- modify config to ignore linting of kiro and changelog ([#831](https://github.com/aws-games/cloud-game-development-toolkit/issues/831))
- update base_infrastructure.ps1 to use IMDSv2 ([#922](https://github.com/aws-games/cloud-game-development-toolkit/issues/922))
- add required filter to s3 lifecycle rule, fix iam policy attachm… ([#732](https://github.com/aws-games/cloud-game-development-toolkit/issues/732))
- update url in http data source ([#733](https://github.com/aws-games/cloud-game-development-toolkit/issues/733))
- remove CodeQL workflow ([#941](https://github.com/aws-games/cloud-game-development-toolkit/issues/941))
- add g6 instance type support for driver installation in vdi module ([#766](https://github.com/aws-games/cloud-game-development-toolkit/issues/766))
- Fix pre-commit terraform-docs version mismatches and validation failures ([#790](https://github.com/aws-games/cloud-game-development-toolkit/issues/790))
- Adjusting timeout on packer template for UE VDI AMI ([#863](https://github.com/aws-games/cloud-game-development-toolkit/issues/863))
- resolving minor linting errors ([#840](https://github.com/aws-games/cloud-game-development-toolkit/issues/840))
- **ci:** include .tftest.hcl files in terraform fmt pre-commit hook ([#872](https://github.com/aws-games/cloud-game-development-toolkit/issues/872))
- **ci:** optimize pre-commit workflow to prevent disk space errors
- **horde:** allow containers to access internal ALB ([#853](https://github.com/aws-games/cloud-game-development-toolkit/issues/853))
- **horde:** migrate iam policies off of deprecated managed_policy_arns
- **p4:** bump ebs volume mounting retry count ([#815](https://github.com/aws-games/cloud-game-development-toolkit/issues/815))
- **p4:** remove busticated depends_on ([#816](https://github.com/aws-games/cloud-game-development-toolkit/issues/816))
- **p4-code-review:** set SWARM_FORCE_EXT to fix token rollover ([#682](https://github.com/aws-games/cloud-game-development-toolkit/issues/682))
- **p4-code-review:** SWARM_HOST should be an https url ([#749](https://github.com/aws-games/cloud-game-development-toolkit/issues/749))
- **perforce:** Perforce Code Review ECS tasks failing deployment ([#760](https://github.com/aws-games/cloud-game-development-toolkit/issues/760))
- **perforce:** restructure tests and fix pre-existing module bugs ([#870](https://github.com/aws-games/cloud-game-development-toolkit/issues/870))
- **perforce:** fix typo in generating p4 auth service url ([#814](https://github.com/aws-games/cloud-game-development-toolkit/issues/814))
- **perforce:** add retry logic for helix-swarm install and fix a2enco… ([#910](https://github.com/aws-games/cloud-game-development-toolkit/issues/910))
- **samples:** update simple-build-pipeline for P4CR EC2 migration ([#904](https://github.com/aws-games/cloud-game-development-toolkit/issues/904))
- **teamcity:** auto-restart ECS service on RDS password rotation ([#937](https://github.com/aws-games/cloud-game-development-toolkit/issues/937))
- **teamcity:** Adjusted agent task definition to available Fargate configuration ([#738](https://github.com/aws-games/cloud-game-development-toolkit/issues/738))
- **unity-license:** Adds conditional creation of sg for ENIs when using existing ([#769](https://github.com/aws-games/cloud-game-development-toolkit/issues/769))
- **unity-license-server:** use traffic-port for health check
- **unreal:** add Checkov skip annotations to Lore module ([#946](https://github.com/aws-games/cloud-game-development-toolkit/issues/946))
- **workflows:** prevent script injection in docs-cleanup workflow ([#896](https://github.com/aws-games/cloud-game-development-toolkit/issues/896))

### Chore
- **all:** Updates provider versions to use '~>' and updates READMEs to reflect that change.
- **deps:** update mkdocs requirement from >=1.4.0 to >=1.6.1 in /docs ([#931](https://github.com/aws-games/cloud-game-development-toolkit/issues/931))
- **deps:** bump actions/github-script from 8.0.0 to 9.0.0 ([#934](https://github.com/aws-games/cloud-game-development-toolkit/issues/934))
- **deps:** bump actions/setup-node from 6.3.0 to 6.4.0 ([#930](https://github.com/aws-games/cloud-game-development-toolkit/issues/930))
- **deps:** bump github/codeql-action from 4.35.1 to 4.35.5 ([#932](https://github.com/aws-games/cloud-game-development-toolkit/issues/932))
- **deps:** bump release-drafter/release-drafter from 7.2.0 to 7.3.0 ([#933](https://github.com/aws-games/cloud-game-development-toolkit/issues/933))
- **deps:** bump actions/upload-artifact from 7.0.0 to 7.0.1 ([#935](https://github.com/aws-games/cloud-game-development-toolkit/issues/935))
- **deps:** update pymdown-extensions requirement from >=10.21.2 to >=10.21.3 in /docs ([#936](https://github.com/aws-games/cloud-game-development-toolkit/issues/936))
- **deps:** bump terraform-linters/setup-tflint from 6.2.1 to 6.2.2 ([#905](https://github.com/aws-games/cloud-game-development-toolkit/issues/905))
- **deps:** bump github/codeql-action from 4.34.1 to 4.35.1 ([#909](https://github.com/aws-games/cloud-game-development-toolkit/issues/909))
- **deps:** bump bridgecrewio/checkov-action from 12.3089.0 to 12.3101.0 ([#911](https://github.com/aws-games/cloud-game-development-toolkit/issues/911))
- **deps:** bump marocchino/sticky-pull-request-comment from 3.0.2 to 3.0.4 ([#912](https://github.com/aws-games/cloud-game-development-toolkit/issues/912))
- **deps:** bump release-drafter/release-drafter from 7.1.1 to 7.2.0 ([#913](https://github.com/aws-games/cloud-game-development-toolkit/issues/913))
- **deps:** bump mike from 2.1.4 to 2.2.0 in /docs ([#915](https://github.com/aws-games/cloud-game-development-toolkit/issues/915))
- **deps:** update mkdocs-same-dir requirement from >=0.1.3 to >=0.1.5 in /docs ([#923](https://github.com/aws-games/cloud-game-development-toolkit/issues/923))
- **deps:** update mkdocs-open-in-new-tab requirement from >=1.0.2 to >=1.0.8 in /docs ([#924](https://github.com/aws-games/cloud-game-development-toolkit/issues/924))
- **deps:** update mkdocs-material requirement from >=9.0.0 to >=9.7.6 in /docs ([#925](https://github.com/aws-games/cloud-game-development-toolkit/issues/925))
- **deps:** update mkdocs-redirects requirement from >=v1.2.2 to >=1.2.3 in /docs ([#928](https://github.com/aws-games/cloud-game-development-toolkit/issues/928))
- **deps:** update pymdown-extensions requirement from >=9.0 to >=10.21.2 in /docs ([#926](https://github.com/aws-games/cloud-game-development-toolkit/issues/926))
- **deps:** bump github/codeql-action from 4.32.5 to 4.32.6 ([#897](https://github.com/aws-games/cloud-game-development-toolkit/issues/897))
- **deps:** bump bridgecrewio/checkov-action from 12.3087.0 to 12.3088.0 ([#899](https://github.com/aws-games/cloud-game-development-toolkit/issues/899))
- **deps:** bump dorny/paths-filter from 3.0.2 to 4.0.0 ([#900](https://github.com/aws-games/cloud-game-development-toolkit/issues/900))
- **deps:** bump release-drafter/release-drafter from 6.2.0 to 7.0.0 ([#901](https://github.com/aws-games/cloud-game-development-toolkit/issues/901))
- **deps:** bump marocchino/sticky-pull-request-comment from 2.9.4 to 3.0.2 ([#902](https://github.com/aws-games/cloud-game-development-toolkit/issues/902))
- **deps:** bump squidfunk/mkdocs-material from 9.7.5 to 9.7.6 in /docs ([#903](https://github.com/aws-games/cloud-game-development-toolkit/issues/903))
- **deps:** bump actions/upload-artifact from 6.0.0 to 7.0.0 ([#886](https://github.com/aws-games/cloud-game-development-toolkit/issues/886))
- **deps:** bump tj-actions/changed-files from 47.0.4 to 47.0.5 ([#889](https://github.com/aws-games/cloud-game-development-toolkit/issues/889))
- **deps:** bump actions/setup-node from 6.2.0 to 6.3.0 ([#890](https://github.com/aws-games/cloud-game-development-toolkit/issues/890))
- **deps:** bump actions/dependency-review-action from 4.8.3 to 4.9.0 ([#891](https://github.com/aws-games/cloud-game-development-toolkit/issues/891))
- **deps:** bump bridgecrewio/checkov-action from 12.3086.0 to 12.3087.0 ([#892](https://github.com/aws-games/cloud-game-development-toolkit/issues/892))
- **deps:** bump mike from 2.1.3 to 2.1.4 in /docs ([#894](https://github.com/aws-games/cloud-game-development-toolkit/issues/894))
- **deps:** bump squidfunk/mkdocs-material from 9.7.3 to 9.7.5 in /docs ([#895](https://github.com/aws-games/cloud-game-development-toolkit/issues/895))
- **deps:** bump github/codeql-action from 4.32.3 to 4.32.4 ([#879](https://github.com/aws-games/cloud-game-development-toolkit/issues/879))
- **deps:** bump actions/dependency-review-action from 4.8.2 to 4.8.3 ([#880](https://github.com/aws-games/cloud-game-development-toolkit/issues/880))
- **deps:** bump bridgecrewio/checkov-action from 12.3084.0 to 12.3086.0 ([#881](https://github.com/aws-games/cloud-game-development-toolkit/issues/881))
- **deps:** bump squidfunk/mkdocs-material from 9.7.2 to 9.7.3 in /docs ([#882](https://github.com/aws-games/cloud-game-development-toolkit/issues/882))
- **deps:** bump hashicorp/setup-terraform from 3.1.2 to 4.0.0 ([#883](https://github.com/aws-games/cloud-game-development-toolkit/issues/883))
- **deps:** bump lycheeverse/lychee-action from 2.7.0 to 2.8.0 ([#884](https://github.com/aws-games/cloud-game-development-toolkit/issues/884))
- **deps:** bump tj-actions/changed-files from 47.0.2 to 47.0.4 ([#873](https://github.com/aws-games/cloud-game-development-toolkit/issues/873))
- **deps:** bump squidfunk/mkdocs-material from 9.7.1 to 9.7.2 in /docs ([#877](https://github.com/aws-games/cloud-game-development-toolkit/issues/877))
- **deps:** bump bridgecrewio/checkov-action from 12.3077.0 to 12.3084.0 ([#878](https://github.com/aws-games/cloud-game-development-toolkit/issues/878))
- **deps:** bump github/codeql-action from 4.32.1 to 4.32.3 ([#867](https://github.com/aws-games/cloud-game-development-toolkit/issues/867))
- **deps:** bump tj-actions/changed-files from 47.0.1 to 47.0.2 ([#868](https://github.com/aws-games/cloud-game-development-toolkit/issues/868))
- **deps:** bump actions/setup-node from 6.1.0 to 6.2.0 ([#856](https://github.com/aws-games/cloud-game-development-toolkit/issues/856))
- **deps:** bump release-drafter/release-drafter from 6.1.0 to 6.2.0 ([#858](https://github.com/aws-games/cloud-game-development-toolkit/issues/858))
- **deps:** bump actions/checkout from 6.0.1 to 6.0.2 ([#859](https://github.com/aws-games/cloud-game-development-toolkit/issues/859))
- **deps:** bump github/codeql-action from 4.31.9 to 4.32.0 ([#861](https://github.com/aws-games/cloud-game-development-toolkit/issues/861))
- **deps:** bump bridgecrewio/checkov-action from 12.3075.0 to 12.3077.0 ([#851](https://github.com/aws-games/cloud-game-development-toolkit/issues/851))
- **deps:** bump squidfunk/mkdocs-material from 9.7.0 to 9.7.1 in /docs ([#847](https://github.com/aws-games/cloud-game-development-toolkit/issues/847))
- **deps:** bump tj-actions/changed-files from 47.0.0 to 47.0.1 ([#844](https://github.com/aws-games/cloud-game-development-toolkit/issues/844))
- **deps:** bump actions/setup-node from 4.4.0 to 6.1.0 ([#845](https://github.com/aws-games/cloud-game-development-toolkit/issues/845))
- **deps:** bump actions/checkout from 4 to 6 ([#823](https://github.com/aws-games/cloud-game-development-toolkit/issues/823))
- **deps:** bump tj-actions/changed-files from 45 to 47 ([#824](https://github.com/aws-games/cloud-game-development-toolkit/issues/824))
- **deps:** bump actions/setup-python from 5 to 6 ([#825](https://github.com/aws-games/cloud-game-development-toolkit/issues/825))
- **deps:** bump actions/github-script from 7 to 8 ([#827](https://github.com/aws-games/cloud-game-development-toolkit/issues/827))
- **deps:** bump github/codeql-action from 4.31.8 to 4.31.9 ([#819](https://github.com/aws-games/cloud-game-development-toolkit/issues/819))
- **deps:** bump terraform-linters/setup-tflint from 4 to 6 ([#806](https://github.com/aws-games/cloud-game-development-toolkit/issues/806))
- **deps:** bump actions/upload-artifact from 5.0.0 to 6.0.0 ([#805](https://github.com/aws-games/cloud-game-development-toolkit/issues/805))
- **deps:** bump actions/github-script from 7 to 8 ([#807](https://github.com/aws-games/cloud-game-development-toolkit/issues/807))
- **deps:** bump actions/checkout from 5.0.1 to 6.0.1 ([#808](https://github.com/aws-games/cloud-game-development-toolkit/issues/808))
- **deps:** bump actions/checkout from 5 to 6 ([#795](https://github.com/aws-games/cloud-game-development-toolkit/issues/795))
- **deps:** bump github/codeql-action from 4.31.0 to 4.31.7 ([#798](https://github.com/aws-games/cloud-game-development-toolkit/issues/798))
- **deps:** bump squidfunk/mkdocs-material from 9.6.22 to 9.7.0 in /docs ([#791](https://github.com/aws-games/cloud-game-development-toolkit/issues/791))
- **deps:** bump terraform-linters/setup-tflint from 5 to 6 ([#753](https://github.com/aws-games/cloud-game-development-toolkit/issues/753))
- **deps:** bump aws-actions/configure-aws-credentials from 5 to 6 ([#755](https://github.com/aws-games/cloud-game-development-toolkit/issues/755))
- **deps:** bump github/codeql-action from 3.30.7 to 4.31.0
- **deps:** bump actions/upload-artifact from 4.6.2 to 5.0.0 ([#773](https://github.com/aws-games/cloud-game-development-toolkit/issues/773))
- **deps:** bump squidfunk/mkdocs-material from 9.6.19 to 9.6.22 in /docs ([#763](https://github.com/aws-games/cloud-game-development-toolkit/issues/763))
- **deps:** bump ossf/scorecard-action from 2.4.2 to 2.4.3
- **deps:** bump github/codeql-action from 3 to 4 ([#754](https://github.com/aws-games/cloud-game-development-toolkit/issues/754))
- **deps:** bump aws-actions/configure-aws-credentials from 4 to 5
- **deps:** bump aquasecurity/trivy-action from 0.31.0 to 0.33.1
- **deps:** bump actions/setup-python from 5 to 6
- **deps:** bump actions/github-script from 7 to 8
- **deps:** bump squidfunk/mkdocs-material in /docs
- **deps:** bump squidfunk/mkdocs-material from 9.6.17 to 9.6.18 in /docs ([#711](https://github.com/aws-games/cloud-game-development-toolkit/issues/711))
- **deps:** bump squidfunk/mkdocs-material from 9.6.16 to 9.6.17 in /docs ([#707](https://github.com/aws-games/cloud-game-development-toolkit/issues/707))
- **deps:** bump terraform-linters/setup-tflint from 4 to 5 ([#703](https://github.com/aws-games/cloud-game-development-toolkit/issues/703))
- **deps:** bump actions/checkout from 4 to 5 ([#700](https://github.com/aws-games/cloud-game-development-toolkit/issues/700))
- **deps:** bump actions/setup-python from 4 to 5 ([#690](https://github.com/aws-games/cloud-game-development-toolkit/issues/690))
- **unity-accelerator:** update provider versions to 6.6.0 ([#759](https://github.com/aws-games/cloud-game-development-toolkit/issues/759))
- **unity-floating-license-server:** add private IP output ([#758](https://github.com/aws-games/cloud-game-development-toolkit/issues/758))

### Code Refactoring
- add additional iam policy support and fix coalesce error ([#765](https://github.com/aws-games/cloud-game-development-toolkit/issues/765))
- **docs:** rename section index files to README.md ([#869](https://github.com/aws-games/cloud-game-development-toolkit/issues/869))
- **vdi:** Packer VDI template supports autogen password ([#708](https://github.com/aws-games/cloud-game-development-toolkit/issues/708))

### Docs
- fixing remaining lint issues ([#839](https://github.com/aws-games/cloud-game-development-toolkit/issues/839))
- linting fixes for perforce docs ([#838](https://github.com/aws-games/cloud-game-development-toolkit/issues/838))
- linting fixes for assets/ documentation ([#837](https://github.com/aws-games/cloud-game-development-toolkit/issues/837))
- linting fixes for docs/ and modules/ READMEs ([#836](https://github.com/aws-games/cloud-game-development-toolkit/issues/836))
- linting fixes to root directory READMEs
- wrap terraform generated docs in lint ignore comments ([#832](https://github.com/aws-games/cloud-game-development-toolkit/issues/832))
- AI agent guidelines ([#809](https://github.com/aws-games/cloud-game-development-toolkit/issues/809))
- add links to p4-server ansible playbooks ([#710](https://github.com/aws-games/cloud-game-development-toolkit/issues/710))
- **vdi:** add testing/development-only notice ([#948](https://github.com/aws-games/cloud-game-development-toolkit/issues/948))

### Features
- add automated release workflow (tag-triggered) ([#943](https://github.com/aws-games/cloud-game-development-toolkit/issues/943))
- Add ODCR support to VDI module and Packer templates ([#747](https://github.com/aws-games/cloud-game-development-toolkit/issues/747))
- **horde:** windows agent auto-install ([#780](https://github.com/aws-games/cloud-game-development-toolkit/issues/780))
- **horde:** optionally run `p4 trust` on the Horde server ([#698](https://github.com/aws-games/cloud-game-development-toolkit/issues/698))
- **horde:** parameterize dotnet version installed on agents ([#706](https://github.com/aws-games/cloud-game-development-toolkit/issues/706))
- **horde:** agent fixes ([#810](https://github.com/aws-games/cloud-game-development-toolkit/issues/810))
- **horde:** allow disabling ASGs ([#811](https://github.com/aws-games/cloud-game-development-toolkit/issues/811))
- **p4:** add p4charset support to p4-code-review ([#689](https://github.com/aws-games/cloud-game-development-toolkit/issues/689))
- **p4:** support passing scim params to p4-code-review
- **p4:** add services ALB HTTPS redirect ([#685](https://github.com/aws-games/cloud-game-development-toolkit/issues/685))
- **p4:** validate that DNS zones and p4 FQDN match
- **p4:** cr and auth derive p4d_port from p4_server when possible
- **p4:** allow passing p4d_port to p4-auth
- **p4-auth:** add support for extra env variables for IDP configuration ([#767](https://github.com/aws-games/cloud-game-development-toolkit/issues/767))
- **p4-cr:** add support for injecting config ([#846](https://github.com/aws-games/cloud-game-development-toolkit/issues/846))
- **perforce:** Add unit tests and fix terraform validation workflow ([#849](https://github.com/aws-games/cloud-game-development-toolkit/issues/849))
- **samples:** add Unity build pipeline with TeamCity integration ([#775](https://github.com/aws-games/cloud-game-development-toolkit/issues/775))
- **teamcity:** fix service connect with external clusters and add custom env vars
- **unity:** deploy floating licensing server ([#429](https://github.com/aws-games/cloud-game-development-toolkit/issues/429)) ([#745](https://github.com/aws-games/cloud-game-development-toolkit/issues/745))
- **unreal:** add Lore VCS module ([#944](https://github.com/aws-games/cloud-game-development-toolkit/issues/944))


<a name="latest"></a>
## [latest] - 2025-07-29

<a name="v1.1.5"></a>
## [v1.1.5] - 2025-07-29
### Bug Fixes
- fixes button/link to getting started page in homepage
- update perforce tf test to support branches on forks as well as source repo
- Minor Perforce module copy/paste naming resolution ([#645](https://github.com/aws-games/cloud-game-development-toolkit/issues/645))
- Fixes typo in code block in samples DDC readme
- hardcode protocol to appease checkov
- Update SG reference in P4 FSxN Example ([#640](https://github.com/aws-games/cloud-game-development-toolkit/issues/640))
- **p4:** Fix typo'ed output.shared_application_load_balancer_arn

### Chore
- regenerate CHANGELOG.md for 2025-07-29
- update dependabot configuration
- remove kevon from description :( ([#672](https://github.com/aws-games/cloud-game-development-toolkit/issues/672))
- **deps:** bump squidfunk/mkdocs-material in /docs
- **deps:** bump NetApp/netapp-ontap
- **deps:** bump NetApp/netapp-ontap in /samples/simple-build-pipeline
- **deps:** bump the awscc-provider group across 3 directories with 1 update
- **deps:** bump the random-provider group across 9 directories with 1 update ([#653](https://github.com/aws-games/cloud-game-development-toolkit/issues/653))
- **deps:** bump the aws-provider group across 8 directories with 1 update ([#662](https://github.com/aws-games/cloud-game-development-toolkit/issues/662))
- **deps:** bump hashicorp/local in /modules/perforce/modules/p4-server
- **deps:** bump hashicorp/local in /modules/perforce
- **deps:** bump the aws-provider group across 8 directories with 1 update
- **deps:** bump squidfunk/mkdocs-material in /docs
- **deps:** bump ossf/scorecard-action from 2.4.1 to 2.4.2
- **deps:** bump aquasecurity/trivy-action from 0.30.0 to 0.31.0

### Docs
- fixed broken links in getting started guide
- **horde:** add alb http listeners to README.md

### Features
- Packer template for Cloud Game Development virtual workstation AMI ([#651](https://github.com/aws-games/cloud-game-development-toolkit/issues/651))
- Unity Accelerator asset caching proxy
- **horde:** allow users to bring their own horde-server images ([#643](https://github.com/aws-games/cloud-game-development-toolkit/issues/643))
- **horde:** add HTTP redirect listeners to ALBs
- **p4:** allow users to specify a private ip ([#665](https://github.com/aws-games/cloud-game-development-toolkit/issues/665))
- **p4:** p4_configure.sh attempts to use --fqdn if passed ([#666](https://github.com/aws-games/cloud-game-development-toolkit/issues/666))


<a name="v1.1.4"></a>
## [v1.1.4] - 2025-06-09
### Bug Fixes
- Remove commented out NetApp volume resources and cleanup IAM managed policies
- Resolved EC2 DNS self-signed certificate bug in P4 Server packer template
- Adding cloud DDC sample for mkdocs.yml
- **helix swarm:** helix swarm does not support horizontal scaling, so helix swarm container count is now set to 1

### Chore
- Add Terraform tests for new Perforce module ([#604](https://github.com/aws-games/cloud-game-development-toolkit/issues/604))
- regenerate CHANGELOG.md for 2025-03-19
- Minor maintenance to Helix Core module
- Minor Helix Authentication fixes
- regenerate CHANGELOG.md for 2025-06-09
- Addressed IAM policy warnings for Helix Swarm
- **deps:** bump actions/github-script from 6 to 7
- **deps:** bump mkdocs-material from 9.6.11 to 9.6.12 in /docs
- **deps:** bump xt0rted/pull-request-comment-branch from 1 to 3
- **deps:** bump actions/checkout from 3 to 4
- **deps:** bump squidfunk/mkdocs-material in /docs
- **deps:** bump mkdocs-material from 9.6.9 to 9.6.11 in /docs
- **deps:** bump squidfunk/mkdocs-material in /docs
- **deps:** bump aquasecurity/trivy-action from 0.29.0 to 0.30.0
- **deps:** bump mkdocs-material from 9.6.8 to 9.6.9 in /docs
- **deps:** bump squidfunk/mkdocs-material from 9.6.8 to 9.6.9 in /docs
- **deps:** bump actions/upload-artifact from 4.6.1 to 4.6.2
- **deps:** bump the awscc-provider group across 2 directories with 1 update
- **deps:** bump mkdocs-material from 9.6.12 to 9.6.14 in /docs

### Code Refactoring
- Update Simple Build Pipeline sample to use new Perforce parent module ([#608](https://github.com/aws-games/cloud-game-development-toolkit/issues/608))
- Perforce modules consolidated to simplify shared resource creation ([#585](https://github.com/aws-games/cloud-game-development-toolkit/issues/585))
- Updated Perforce complete example to remove NLB front for Helix Core
- reorganize unreal cloud ddc module structure

### Docs
- Adjustments to mkdocs structure, and updates to "getting started" and Perforce documentation. ([#612](https://github.com/aws-games/cloud-game-development-toolkit/issues/612))
- updates and expands on `unreal-cloud-ddc-intra-cluster` installation and usage docs
- fixes relative path for `unreal-cloud-ddc-infra` and `unreal-cloud-ddc-intra-cluster` Terraform module docs
- add unreal fest video to horde module
- **TeamCity:** Adding TeamCity module docs and example architecture

### Features
- Adds debug variable and flag
- Simple example deployment of Helix Core backed by FSxN
- FSxN ISCSI provisioning for Helix Core module
- Modified p4_configure.sh to mount ISCSI volumes from FSxN


<a name="v1.1.3-alpha"></a>
## [v1.1.3-alpha] - 2025-03-19
### Bug Fixes
- create_external_alb shouldn't block internal SG Ingress rules
- alb_subnet variables should not be required if create boolean is false
- Attaching perforce web service ALB to target group
- use provided admin password secret for Helix Authentication Service ADMIN_PASSWD, instead of the username secret
- AMI version bump for Helix Core, region variable made optional

### Chore
- update dependabot configuration to include unreal modules
- **deps:** bump the aws-provider group across 5 directories with 1 update
- **deps:** bump mkdocs-material from 9.6.4 to 9.6.7 in /docs
- **deps:** bump the awscc-provider group across 2 directories with 1 update
- **deps:** bump the awscc-provider group across 2 directories with 1 update
- **deps:** bump squidfunk/mkdocs-material from 9.6.4 to 9.6.7 in /docs
- **deps:** bump the awscc-provider group across 2 directories with 1 update
- **deps:** bump actions/upload-artifact from 4.6.0 to 4.6.1
- **deps:** bump ossf/scorecard-action from 2.4.0 to 2.4.1
- **deps:** bump hashicorp/random
- **deps:** bump the awscc-provider group across 2 directories with 1 update
- **deps:** bump the aws-provider group across 5 directories with 1 update
- **deps:** bump squidfunk/mkdocs-material from 9.6.7 to 9.6.8 in /docs
- **deps:** bump the random-provider group across 4 directories with 1 update
- **deps:** bump mkdocs-material from 9.6.3 to 9.6.4 in /docs
- **deps:** bump the aws-provider group across 5 directories with 1 update
- **deps:** bump squidfunk/mkdocs-material from 9.6.2 to 9.6.4 in /docs
- **deps:** bump actions/upload-artifact from 4.5.0 to 4.6.0
- **deps:** bump mkdocs-material from 9.6.7 to 9.6.8 in /docs
- **deps:** bump hashicorp/aws
- **deps:** bump mkdocs-material from 9.6.2 to 9.6.3 in /docs
- **deps:** bump squidfunk/mkdocs-material from 9.6.1 to 9.6.2 in /docs
- **deps:** bump mkdocs-material from 9.5.50 to 9.6.2 in /docs
- **deps:** bump the aws-provider group across 5 directories with 1 update
- **deps:** bump squidfunk/mkdocs-material in /docs
- **deps:** bump the awscc-provider group across 2 directories with 1 update
- **deps:** bump aws-actions/configure-aws-credentials
- **deps:** bump the aws-provider group across 5 directories with 1 update
- **deps:** bump the awscc-provider group across 3 directories with 1 update
- **deps:** bump squidfunk/mkdocs-material in /docs
- **deps:** bump release-drafter/release-drafter from 6.0.0 to 6.1.0
- **deps:** bump mkdocs-material from 9.5.49 to 9.5.50 in /docs
- **deps:** bump the awscc-provider group across 3 directories with 1 update
- **deps:** bump the aws-provider group across 5 directories with 1 update
- **deps:** bump aws-actions/configure-aws-credentials
- **deps:** bump the aws-provider group across 5 directories with 1 update

### Docs
- fix broken link in readme
- **Perforce:** Updating documentation for Perforce Complete example reference architecture

### Features
- **Helix Authentication Service:** Shifting ALB creation to support external networking configuration
- **Helix Core:** Plaintext support for Helix Core, optional EIP creation
- **Helix Core:** Adding plaintext variable to p4_configre.sh
- **Helix Swarm:** Shifting ALB creation to support external networking configuration
- **Perforce Example:** Update complete example for shared networking configuration across services
- **TeamCity Example:** example terraform configuration for deploying TeamCity module
- **TeamCity Server:** terraform module for deploying TeamCity server on ECS Fargate


<a name="v1.1.2-alpha"></a>
## [v1.1.2-alpha] - 2024-12-20
### Chore
- regenerate CHANGELOG.md for 2024-12-20
- ignore tf backend.tf files in .gitignore
- **deps:** bump the awscc-provider group across 3 directories with 1 update
- **deps:** bump actions/upload-artifact from 4.4.3 to 4.5.0
- **deps:** bump the aws-provider group across 5 directories with 1 update

### Docs
- removed READMEs from source directories and moved them to their own dedicated docs pages in docs/ dir
- update contributor documentation to include table of contents
- updates to doc formatting and fixed broken links


<a name="v1.1.1-alpha"></a>
## [v1.1.1-alpha] - 2024-12-17
### Bug Fixes
- Added service target group ARNs as outputs for HAS and Swarm
- Adds defaults to `vpc_id` and `subnet_id` variables
- bash error causing build failure when running p4_configure.sh ([#367](https://github.com/aws-games/cloud-game-development-toolkit/issues/367))
- **horde:** add JwtIssuer to ensure container retains agents on restart
- **horde:** allow inbound access to horde agents on ports 7000-7010 from other horde agents
- **perforce:** fixed minor issues in p4_configure.sh
- **perforce:** add Unicode support and fix main module to handle existing security groups

### Chore
- make SELinux label updates configurable
- remove packer assets .ci directory ([#337](https://github.com/aws-games/cloud-game-development-toolkit/issues/337))
- fix tag names so that they match recommended best practices ([#343](https://github.com/aws-games/cloud-game-development-toolkit/issues/343))
- define nat gateway routes for private route tables outside of aws_route_table resources in samples and modules ([#354](https://github.com/aws-games/cloud-game-development-toolkit/issues/354))
- adds triage label to our issue templates
- regenerate CHANGELOG.md for 2024-12-17
- document parameter values for '--unicode' flag
- provide appropriate association name for configuring Helix Core via SSM
- fix naming
- **checkov:** Suppresses CKV_AWS_378 rule ([#339](https://github.com/aws-games/cloud-game-development-toolkit/issues/339))
- **deps:** bump mkdocs-material from 9.5.42 to 9.5.44 in /docs
- **deps:** bump the awscc-provider group across 3 directories with 1 update
- **deps:** bump aquasecurity/trivy-action from 0.28.0 to 0.29.0
- **deps:** bump mkdocs-material from 9.5.45 to 9.5.46 in /docs
- **deps:** bump the aws-provider group across 5 directories with 1 update
- **deps:** bump mkdocs-material from 9.5.44 to 9.5.45 in /docs
- **deps:** bump mkdocs-open-in-new-tab from 1.0.7 to 1.0.8 in /docs
- **deps:** bump the aws-provider group across 5 directories with 1 update
- **deps:** bump actions/checkout from 3.0.0 to 4.2.2
- **deps:** bump the awscc-provider group across 3 directories with 1 update
- **deps:** bump the aws-provider group across 5 directories with 1 update
- **deps:** bump hashicorp/setup-terraform from 1 to 3
- **deps:** bump aws-actions/configure-aws-credentials
- **deps:** bump mkdocs-material from 9.5.41 to 9.5.42 in /docs
- **deps:** bump mkdocs-open-in-new-tab from 1.0.6 to 1.0.7 in /docs
- **deps:** bump the awscc-provider group across 3 directories with 1 update
- **deps:** bump the aws-provider group across 5 directories with 1 update
- **deps:** bump aquasecurity/trivy-action from 0.24.0 to 0.28.0
- **deps:** bump mkdocs-material from 9.5.40 to 9.5.41 in /docs
- **deps:** bump the awscc-provider group across 3 directories with 1 update
- **deps:** bump python from 3.12.7 to 3.13.0 in /docs ([#349](https://github.com/aws-games/cloud-game-development-toolkit/issues/349))
- **deps:** bump actions/upload-artifact from 4.4.0 to 4.4.3 ([#356](https://github.com/aws-games/cloud-game-development-toolkit/issues/356))
- **deps:** bump mkdocs-material from 9.5.39 to 9.5.40 in /docs ([#359](https://github.com/aws-games/cloud-game-development-toolkit/issues/359))
- **deps:** bump mkdocs-open-in-new-tab from 1.0.5 to 1.0.6 in /docs ([#345](https://github.com/aws-games/cloud-game-development-toolkit/issues/345))
- **deps:** bump the aws-provider group across 5 directories with 1 update
- **deps:** bump mkdocs-material from 9.5.37 to 9.5.39 in /docs ([#335](https://github.com/aws-games/cloud-game-development-toolkit/issues/335))
- **deps:** bump the aws-provider group across 5 directories with 1 update ([#344](https://github.com/aws-games/cloud-game-development-toolkit/issues/344))
- **deps:** bump mkdocs-material from 9.5.46 to 9.5.48 in /docs
- **deps:** bump python from 3.12.6 to 3.12.7 in /docs ([#340](https://github.com/aws-games/cloud-game-development-toolkit/issues/340))
- **deps:** bump mkdocs-material from 9.5.48 to 9.5.49 in /docs
- **deps:** bump python from 3.13.0 to 3.13.1 in /docs

### Docs
- clarify that modules are intended to be depended on, and samples are reference implementations meant to be copied and modified
- fix formatting of simple build pipeline docs
- fix formatting of local.tf in simple build pipeline docs
- fix formatting of jenkins pipeline assets page
- clarify use case of Ansible playbooks vs Packer templates
- clarify that deploying multiple samples independently is not supported
- point users explicitly to a Classic GitHub Personal Access Token
- fix typo in getting started guide
- Updates the getting started instructions for the simple build pipeline sample

### Features
- **perforce:** implement Helix Core setup playbook


<a name="v1.1.0-alpha"></a>
## [v1.1.0-alpha] - 2024-10-01
### Bug Fixes
- improve stability of build agent packer scripts, adjust winrm timeout to 15 minutes, remove packer variables that aren't needed ([#318](https://github.com/aws-games/cloud-game-development-toolkit/issues/318))

### Chore
- update changelog ([#305](https://github.com/aws-games/cloud-game-development-toolkit/issues/305))
- **deps:** bump the awscc-provider group across 3 directories with 1 update ([#323](https://github.com/aws-games/cloud-game-development-toolkit/issues/323))
- **deps:** bump mkdocs-material from 9.5.35 to 9.5.37 in /docs ([#314](https://github.com/aws-games/cloud-game-development-toolkit/issues/314))
- **deps:** bump the aws-provider group across 5 directories with 1 update ([#324](https://github.com/aws-games/cloud-game-development-toolkit/issues/324))
- **deps:** bump the aws-provider group across 5 directories with 1 update ([#298](https://github.com/aws-games/cloud-game-development-toolkit/issues/298))
- **deps:** bump the awscc-provider group across 3 directories with 1 update ([#291](https://github.com/aws-games/cloud-game-development-toolkit/issues/291))
- **deps:** bump the random-provider group across 5 directories with 1 update ([#310](https://github.com/aws-games/cloud-game-development-toolkit/issues/310))
- **deps:** bump mkdocs-material from 9.5.34 to 9.5.35 in /docs ([#287](https://github.com/aws-games/cloud-game-development-toolkit/issues/287))

### Docs
- add perforce complete example in docs ([#333](https://github.com/aws-games/cloud-game-development-toolkit/issues/333))
- updates to documentation ([#329](https://github.com/aws-games/cloud-game-development-toolkit/issues/329))

### Features
- install requirements for (auto)mounting FSx volumes on Jenkins Windows build agents ([#319](https://github.com/aws-games/cloud-game-development-toolkit/issues/319))
- **helix-core:** add ARM64 support ([#239](https://github.com/aws-games/cloud-game-development-toolkit/issues/239))


<a name="v1.0.1-alpha"></a>
## [v1.0.1-alpha] - 2024-09-16
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
- update changelog workflow ([#284](https://github.com/aws-games/cloud-game-development-toolkit/issues/284))
- update changelog ([#285](https://github.com/aws-games/cloud-game-development-toolkit/issues/285))
- **deps:** bump hashicorp/awscc from 1.10.0 to 1.11.0 in /samples/simple-build-pipeline ([#220](https://github.com/aws-games/cloud-game-development-toolkit/issues/220))
- **deps:** bump hashicorp/awscc from 1.9.0 to 1.10.0 in /modules/perforce/helix-core ([#207](https://github.com/aws-games/cloud-game-development-toolkit/issues/207))
- **deps:** bump mkdocs-material from 9.5.33 to 9.5.34 in /docs ([#236](https://github.com/aws-games/cloud-game-development-toolkit/issues/236))
- **deps:** bump actions/upload-artifact from 4.3.6 to 4.4.0 ([#235](https://github.com/aws-games/cloud-game-development-toolkit/issues/235))
- **deps:** bump the aws-provider group across 5 directories with 1 update ([#241](https://github.com/aws-games/cloud-game-development-toolkit/issues/241))
- **deps:** bump the awscc-provider group across 3 directories with 1 update ([#242](https://github.com/aws-games/cloud-game-development-toolkit/issues/242))
- **deps:** bump the aws-provider group across 5 directories with 1 update ([#233](https://github.com/aws-games/cloud-game-development-toolkit/issues/233))
- **deps:** bump the aws-provider group across 5 directories with 1 update ([#231](https://github.com/aws-games/cloud-game-development-toolkit/issues/231))
- **deps:** bump mkdocs-material from 9.5.32 to 9.5.33 in /docs ([#229](https://github.com/aws-games/cloud-game-development-toolkit/issues/229))
- **deps:** bump mkdocs-open-in-new-tab from 1.0.3 to 1.0.5 in /docs ([#263](https://github.com/aws-games/cloud-game-development-toolkit/issues/263))
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
## staging - 2024-08-07
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


[Unreleased]: https://github.com/aws-games/cloud-game-development-toolkit/compare/v1.1.6...HEAD
[v1.1.6]: https://github.com/aws-games/cloud-game-development-toolkit/compare/latest...v1.1.6
[latest]: https://github.com/aws-games/cloud-game-development-toolkit/compare/v1.1.5...latest
[v1.1.5]: https://github.com/aws-games/cloud-game-development-toolkit/compare/v1.1.4...v1.1.5
[v1.1.4]: https://github.com/aws-games/cloud-game-development-toolkit/compare/v1.1.3-alpha...v1.1.4
[v1.1.3-alpha]: https://github.com/aws-games/cloud-game-development-toolkit/compare/v1.1.2-alpha...v1.1.3-alpha
[v1.1.2-alpha]: https://github.com/aws-games/cloud-game-development-toolkit/compare/v1.1.1-alpha...v1.1.2-alpha
[v1.1.1-alpha]: https://github.com/aws-games/cloud-game-development-toolkit/compare/v1.1.0-alpha...v1.1.1-alpha
[v1.1.0-alpha]: https://github.com/aws-games/cloud-game-development-toolkit/compare/v1.0.1-alpha...v1.1.0-alpha
[v1.0.1-alpha]: https://github.com/aws-games/cloud-game-development-toolkit/compare/v1.0.0-alpha...v1.0.1-alpha
[v1.0.0-alpha]: https://github.com/aws-games/cloud-game-development-toolkit/compare/staging...v1.0.0-alpha
