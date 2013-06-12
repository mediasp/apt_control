# apt-control

Features:

 - Automatically move debian packages in to your apt repository based on
   gemspec-esque version specifications.

 - Use as part of an automated build and deployment system (i.e. continuous
   deployment) to get your debs in to your apt site

 - Control and query using a jabber bot

Requirements:
 - reprepro based apt site
 - directory full of builds - the build archive
 - ruby1.8 and rubygems
 - jabber server (optional, for notifications)

# install

gem install apt-control-{some-version}.gem

# using

Set up a control.ini file, which lists your repositories and the packages you
want to control, along with gemspec style version rules.

```
# control.ini
[production]
rest-api    = "~> 0.1"
mailer      = "= 1.4.2"

[staging]
rest-api    = ">= 0.1"
mailer      = "= 1.4"
```

Presuming you already have a directory full of builds and a reprepro apt
repository.  Now you can get a dump of the state of your repository and build
archive, which will confirm you've got everything set up properly.

NB: You can set up a config file to avoid passing -o options with each invocation

```
$ apt_control -o control_file=control.ini -o build_archive_dir=builds \
  -o apt_site_dir=apt status

production
  rest-api
    rule        - ~> 0.1
    included    - 0.1.0
    available   - 0.1.0, 0.1.1, 0.2.0
    satisfied   - true
    includeable - true
... # And so on
```

There is more documentation included in the CLI.  Run `apt_control -h` to get
more help.

## watch daemon

`apt_control` comes with a watch command that will watch your build directory for
new packages to arrive, and your control file for any changes made to it.  It
will then perform any include operations that it can according to any new builds
or changed rules.

## jabber bot

The watch daemon can connect to your jabber server, where you can
communicate with the bot and get it to do stuff, like reload the control file,
ask for the status.

The bot commands mostly correspond to the cli commands.

## operations

### include

The include operation will include the highest possible package for each package
rule that you have set up in your apt repository.

 - CLI: `apt_control include`
 - aptbot: `aptbot: include`

## set

Set will set a rule for a particular package, for instance, set the rule for
the `api` package in `production` to be '~> 1.4.1'

 - CLI: `apt_control set production api '~> 1.4.1'`
 - aptbot: `aptbot: set production api '~> 1.4.1'`

## promote

The promote rule is a fancy set that takes the currently included package
from one repository and updates your package rule for the destination repository
to want to include exactly that package.  This is mostly useful for moving a
package from staging in to production.

 - CLI: `apt_control promote staging production api`
 - aptbot: `aptbot: promote staging production api`


