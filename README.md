# Workflow
This repository is a collection of workflow scripts which (hopefully) boost StackRox engineers' productivity. It has scripts for common tasks that need to be executed frequently, and aims to make them simple.

## How To Use

(Mac OS only): Cloning the repo and executing `setup.sh` will automagically do everything you need to set this up. Simply follow the prompts on-screen.

If you're not on Mac OS, or you prefer to do it manually, more detailed instructions follow.

All the scripts are symlinked to in the `bin/` folder, so once you clone the repo, adding the `bin/` folder to your path will allow you to run them. If you're using the `bash` shell, the preferred way to do this is to source the `env.sh` script in every new session. Assuming this repository is checked out to `~/dev/src/bitbucket.org/stack-rox/workflow`, add the following line to your `~/.bash_profile` file:

```sh
source ~/dev/src/bitbucket.org/stack-rox/workflow/env.sh
```

As an alternative, you can also just manually add the `bin/` folder to your path.

There is a `roxhelp` command. You can do `roxhelp --list-all` to see all commands, and `roxhelp <command-name>` to see more about a particular command.

## Config

Some commands require you to have a config file. Copy the `workflow-config.json.example` file from this repo, and paste it in `~/.stackrox/workflow-config.json`; fill in all the fields. (Different commands will require different fields to be set; it's okay for you to not fill in the config entries for, say, Bitbucket, if you don't want to use the commands that require Bitbucket auth.)

Note that you should NOT put in your actual Bitbucket password in the config file; instead, generate an app password following the instructions at https://confluence.atlassian.com/bitbucket/app-passwords-828781300.html, and add that to your config file.
