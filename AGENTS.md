# Hollywood RNG

## Required game checks

Before handing off a Roblox game change, run the type check and rules tests from README.md.

Before merging any pull request into `main`, confirm the GitHub Actions check named
**Game checks** is green. Do not merge while it is missing, running, or failing.

## Agent concurrency

Keep no more than three agents running at once. If three are already active, wait for one to
finish before starting another.
