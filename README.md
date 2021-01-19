# Grit
Grit is just a simple mapping tool to align your multiple repositories. It's just a proxy for git cli commands to your main repo and your other repos. It does not create/delete repositories.  It will only manage what is in your `.grit/config`.

## Grits Goals

* Proxy the git cli
* Not get in the way
* Allow the user to make the normal git choices

## Getting started:
Clone the repo and put the executable in your PATH
```
git clone https://github.com/mlintern/grit.git ~/.grit
chmod +x ~/.grit/grit.rb
ln -s ~/.grit/grit.rb /usr/local/bin/grit
```

### Creating a new project:
```
[master][~/proj-root]$ grit init
```

### Add current git directories
```
[master][~/proj-root]$ grit add-all
```

### Add new git directory
```
[master][~/proj-root]$ grit add-repository <name/dir> <dir (optional)>
```

Will generate .grit/config.yml

## Sample config.yml
```
---
root: /Users/jbond/proj-root
repositories:
  - name: Spectre
    path: frameworks/spectre
  - name: Skyfall
    path: frameworks/skyfall
ignore_root: false
```
### Command Options
```
OPTIONS:

  help                         - display list of commands
  init <dir> (optional)        - create grit config.yml file in .grit dir
  add-all                      - add all directories in the current directory to config.yml
  config                       - show current config settings
  clean-config                 - remove any missing direcotries from config.yml
  convert-config               - convert conf from sym to string
  add-repository <name> <dir>  - add repo and dir to config.yml
  remove-repository <name>     - remove specified repo from config.yml
  destroy                      - delete current grit setup including config and .grit directory
  on <repo> <action>           - execute git action on specific repo
  version                      - get current grit version
```

### Executing Commands:
grit status
```
[master][~/proj-root]$ grit status
Performing operation status on Root
# On branch master
# Your branch is ahead of 'origin/master' by 1 commit.
#
nothing to commit (working directory clean)

Performing operation status on Spectre
# On branch master
nothing to commit (working directory clean)

Performing operation status on Skyfall
# On branch master
nothing to commit (working directory clean)
```

### Executing on a Single Repoository
grit on REPO_NAME_CASE GIT_OPERATION will perform that operation on the repo you want
```
[master][~/proj-root]$ grit on spectre status
# sproutcore$ git st
# On branch master
nothing to commit (working directory clean)
```

### Cleanup Grit Project
grit destroy will remove the .grit directory and config
```
[master][~/proj-root]$ grit destroy
```

### Might want to add .grit/ to global gitignore file
```
git config --global core.excludesfile ~/.gitignore
echo ".grit/" >> ~/.gitignore
```
