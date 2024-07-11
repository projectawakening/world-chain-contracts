⚠️ PLEASE REMOVE THIS TEMPLATE BEFORE SUBMITTING ⚠️

---
## Pull Request template
Please, go through these steps before you submit a PR.

1. Make sure the title of the Pull Request title respects the [Conventional Commits Spec](https://www.conventionalcommits.org/en/v1.0.0/#summary):

    a. Must be in the following format: `{type}({optional link to github issue}): {Description}` (e.g. `fix(#1063): Add missing config variables`, `docs: Add PR template`).

    b. Type must be one of the following:
    * **feat**: A new feature
    * **improvement**: A feature improvement
    * **fix**: A bug fix
    * **docs**: Documentation only changes
    * **perf**: A code change that improves performance
    * **build**: Changes that affect the build system or external dependencies (example scopes: pnpm, yarn)
    * **ci**: Changes to our CI configuration files and scripts
    * **refactor**: A code change that neither fixes a bug nor adds a feature
    * **style**: Changes that do not affect the meaning of the code (white-space, formatting, missing semi-colons, etc)
    * **test**: Adding missing tests or correcting existing tests
    * **chore**: Improving the code base so that it can be worked with more easily

    c. Please write a clear PR description (what, why and how) for your changes. Attach a link to a github issue if there is one.

2. If your Pull Request includes breaking changes:

    a. Add `!` in your PR title after the type. (e.g. `feat!: Upgrade entity_record tables`) or 

    b. Add `BREAKING CHANGE: {Description of the breaking change}` in your PR description. (e.g. `Upgrade entity_record tables`)

⚠️ PLEASE REMOVE THIS TEMPLATE BEFORE SUBMITTING ⚠️