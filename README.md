# apt-control

Automatically move debian packages in to your apt repository based on
gemspec-esque version specifications.  Meant to be used as part of an automated
build and deployment system (i.e. continuous deployment).

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

Now get apt_control to watch your build directory for new packages to arrive,
moving them in to apt as they do, according to the rules you've set up.  This
will then notify your jabber chat room with any operations it performs.

`apt_control watch --daemonize`

There is more documentation included in the CLI.  Run `apt_control -h` to get
more help.