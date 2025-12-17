# Table of contents <!-- omit in toc -->

- [Contributing Guidelines](#contributing-guidelines)
  - [Reporting Bugs/Feature Requests](#reporting-bugsfeature-requests)
  - [Contributing via Pull Requests](#contributing-via-pull-requests)
  - [Conventional Commits](#conventional-commits)
  - [Finding contributions to work on](#finding-contributions-to-work-on)
  - [Code of Conduct](#code-of-conduct)
  - [Security issue notifications](#security-issue-notifications)
  - [Licensing](#licensing)

# Contributing Guidelines

Thank you for your interest in contributing to our project. Whether it's a bug report, new feature, correction, or additional
documentation, we greatly value feedback and contributions from our community.

Please read through this document before submitting any issues or pull requests to ensure we have all the necessary
information to effectively respond to your bug report or contribution.

## Reporting Bugs/Feature Requests

We welcome you to use the GitHub issue tracker to report bugs or suggest features.

When filing an issue, please check existing open, or recently closed, issues to make sure somebody else hasn't already
reported the issue. Please try to include as much information as you can. Details like these are incredibly useful:

- A reproducible test case or series of steps
- The version of our code being used
- Any modifications you've made relevant to the bug
- Anything unusual about your environment or deployment

## Contributing via Pull Requests

Contributions via pull requests are much appreciated. Before sending us a pull request, please ensure that:

1. You are working against the latest source on the *main* branch.
2. You check existing open, and recently merged, pull requests to make sure someone else hasn't addressed the problem already.
3. You open an issue to discuss any significant work - we would hate for your time to be wasted.

To send us a pull request, please:

1. Fork the repository.
2. Modify the source; please focus on the specific change you are contributing. If you also reformat all the code, it will be hard for us to focus on your change.
3. Ensure local tests pass.
4. Commit to your fork using clear commit messages. See the [conventional commits](#conventional-commits) section for more details.
5. Send us a pull request, answering any default questions in the pull request interface.
6. Pay attention to any automated CI failures reported in the pull request, and stay involved in the conversation.

GitHub provides additional document on [forking a repository](https://help.github.com/articles/fork-a-repo/) and
[creating a pull request](https://help.github.com/articles/creating-a-pull-request/).

## Conventional Commits

This project uses [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) following the release of v1.0.0-alpha. These conventions ensure that the commit history of the project remains readable, and supports extensive automation around pull request creation, release cadence, and documentation.

We do not enforce conventional commits on contributors. We do require that pull request titles follow convention so that the changelog and release automation work as expected.

## Finding contributions to work on

Looking at the existing issues is a great way to find something to contribute on. As our projects, by default, use the default GitHub issue labels (enhancement/bug/duplicate/help wanted/invalid/question/wontfix), looking at any 'help wanted' issues is a great place to start.

## Building and Testing Project Documentation

This project uses [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/) to generate documentation. Content is sourced from markdown files throughout the project, including module README.md files.

### Local Development

For day-to-day documentation work, use the container-based local development server:

```bash
make docs-serve
```

This command:

- Builds a container image with all required dependencies
- Starts a local development server at http://127.0.0.1:8000
- Provides live reload - changes appear automatically in your browser
- Requires no Python installation or VERSION/ALIAS parameters
- Works with Docker (default) or Finch by setting `CONTAINER_RUNTIME=finch` in your environment.

To build the documentation without serving it:

```bash
make docs-build
```

This validates that your changes build successfully using `mkdocs build --strict` in a container. The built site will be in the `./site` directory.

### Pre-commit Validation

Documentation is validated automatically before commit:

- **Link checking**: Verifies all links in staged markdown files
- **Markdown linting**: Ensures consistent markdown formatting

Install pre-commit hooks:

```bash
pre-commit install
```

**Optional - Pretty Formatter for Markdownlint:**

For better-looking markdown linting output, you can install the pretty formatter:

```bash
npm install -g markdownlint-cli2-formatter-pretty
```

This is optional but provides cleaner, color-coded output. The linting will work without it.

### Pull Request Validation

When you open a PR with documentation changes:

1. Changed files are validated (links and markdown linting)
2. Full documentation site is built to ensure integrity
3. Preview deployment is created at `preview/pr-{number}`
4. Comment is posted with preview URL

### Main Branch Deployment

When your PR is merged to main:

- Documentation automatically deploys to "latest"
- Full regression testing runs (all files validated)
- Issues are created if validation fails

### Versioned Releases

Versioned documentation is created only for official releases:

1. Use the "Build Docs and Publish to gh-pages" GitHub Action
2. Manually specify VERSION and ALIAS
3. This is done rarely for major/minor releases

## Code of Conduct

This project has adopted the [Amazon Open Source Code of Conduct](https://aws.github.io/code-of-conduct).
For more information see the [Code of Conduct FAQ](https://aws.github.io/code-of-conduct-faq) or contact
opensource-codeofconduct@amazon.com with any additional questions or comments.

## Security issue notifications

If you discover a potential security issue in this project we ask that you notify AWS/Amazon Security via our [vulnerability reporting page](http://aws.amazon.com/security/vulnerability-reporting/). Please do **not** create a public github issue.

## Licensing

See the [LICENSE](https://github.com/aws-games/cloud-game-development-toolkit/blob/main/LICENSE) file for our project's licensing. We will ask you to confirm the licensing of your contribution.
