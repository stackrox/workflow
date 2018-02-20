# Workflow
This repository is a collection of workflow scripts which (hopefully) boost StackRox engineers' productivity. It has scripts for common tasks that need to be executed frequently, and aims to make them simple.

## How To Use
All the scripts are symlinked to in the `bin/` folder. Clone the repo, and add the `bin/` folder to your path. That way, you'll be able to run all the commands by name.

There is a `roxhelp` command. You can do `roxhelp --list-all` to see all commands, and `roxhelp <command-name>` to see more about a particular command.

## Config

Some commands require you to have a config file. Copy the `workflow-config.json.example` file from this repo, and paste it in `~/.stackrox/workflow-config.json`; fill in all the fields. (Different commands will require different fields to be set; it's okay for you to not fill in the config entries for, say, Bitbucket, if you don't want to use the commands that require Bitbucket auth.)

Note that you should NOT put in your actual Bitbucket password in the config file; instead, generate an app password following the instructions at https://confluence.atlassian.com/bitbucket/app-passwords-828781300.html, and add that to your config file.
