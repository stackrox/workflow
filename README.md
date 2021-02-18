# Workflow
This repository is a collection of workflow scripts which (hopefully) boost StackRox engineers' productivity. It has scripts for common tasks that need to be executed frequently, and aims to make them simple.

## Installation

### MacOS

```
$ mkdir -p $GOPATH/src/github.com/stackrox
$ cd $GOPATH/src/github.com/stackrox
$ git clone git@github.com:stackrox/workflow
$ cd workflow
$ ./setup.sh
```

### Manual installation

If you're not on Mac OS, or you prefer to do it manually, more detailed instructions follow.

All the scripts are symlinked to in the `bin/` folder, so once you clone the repo, adding the `bin/` folder to your path will allow you to run them. If you're using the `bash` shell, the preferred way to do this is to source the `env.sh` script in every new session. Assuming this repository is checked out to `~/go/src/github.com/stackrox/workflow`, add the following line to your `~/.bash_profile` file:

```sh
source ~/go/src/github.com/stackrox/workflow/env.sh
```

As an alternative, you can also just manually add the `bin/` folder to your path.

## Commands

```
$ roxhelp --list-all
checkout-pr - Checks out the branch given the PR number.
cycle-branch - Cycles through recently checked out branches.
gcdown - Brings down the GCP dev VM.
gcmosh - Establishes an interactive session to the (running) GCP Dev VM instance via mosh
gcscp - Performs a copy via SSH connection to/from the (running) GCP dev VM.
gcssh - Establishes an SSH connection to the (running) GCP Dev VM instance.
gcup - Brings up the GCP dev VM.
getcreds - Imports credentials for a cluster from setup and creates RBAC role bindings.
getprnumber - Gets the PR number corresponding to the current checked out branch.
gogen - Runs go generate rooted at the current working directory (or a directory specified as the first
killpf - killpf <port> kills a kubectl port-forward running on the passed port, if there is one. Note that it ONLY kills kubectl port-forwards, not arbtirary processes.
logmein - Opens a browser, logging you in as the same user that `roxcurl` uses.
openbranch - Opens the web page corresponding to the currently checked-out branch of the repo you're in.
openjira - Opens the web page corresponding to the JIRA ticket for the branch you're on.
openpr - Opens the web page corresponding to the Pull Request for the currently checked-out branch of the repo you're in.
quickstyle - Runs style targets for all Go/JS files that have changed between the current code and master.
roxcurl - Curls StackRox central at the endpoint specified. If you
roxdebug - Starts dlv debugging session in running pod.
roxhelp - Prints the help message for a Rox workflow command.
roxkubectx - A `kubectl config current-context` wrapper that is aware of setup names.
roxlatestimage - Get the last docker image which is available locally for a given service.
roxlatesttag - Get the last docker tag which is locally available.
smart-branch - Usage: smart-branch (creates and checks out a new branch with marker commits to allow working on multiple dependend branches)
smart-diff - Produces git diff relative to the last smart-branch commit.
smart-rebase - Usage: smart-rebase (given a branch name it rebases multiple dependend branches)
smart-squash - Usage: smart-squash (squashes commits only until the first parent branch marker)
teardown - Tears down a running StackRox installation very quickly, and makes sure no resources we create are left running around.
```

## Config

Some commands require you to have a config file. Copy the `workflow-config.json.example` file from this repo,
and paste it in `~/.stackrox/workflow-config.json`; fill in all the fields.
(Different commands will require different fields to be set; it's okay for you to not fill in the config entries for,
say, Azure, if you don't want to use the commands that require Azure auth.)

If you want to use commands that require GitHub auth, you can generate a token at https://github.com/settings/tokens (it is used to list pull requests and branches, so give it `repo` scope) and add it to the entry in your config.

