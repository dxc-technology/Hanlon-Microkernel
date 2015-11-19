## Changes to the latest Hanlon Microkernel

Recently, we have made significant changes to the Hanlon Microkernel project.
Previous versions of the Hanlon Microkernel project included a set of scripts
that could be used to build a customized Hanlon Microkernel ISO that was used
by Hanlon for node discovery. Starting with version 3.0.0, the Microkernel
itself has been converted from a customized ISO (that was based on Tiny Core
Linux's standard ISO) to a Docker image that, when combined with a RancherOS
ISO, performs the same tasks. The instructions in this document are meant to
aid those who are interested in building their own Hanlon Microkernel images.

The new Hanlon Microkernel (Docker) image is based on the standard Alpine Linux
container. This container provides us with a platform that is both small (an
important consideration for a Microkernel that is intended to be used for
discovery in both small and large datacenter environments) and that includes
pre-built versions of the packages necessary to satisfy he dependencies for our
Microkernel controller (including the `bash`, `sed`, `dmidecode`, `ruby`,
`open-lldp`, `util-linux` (which includes the `lscpu` tool), `open-vm-tools`,
`lshw`, and `ipmitool` packages). A few other dependencies (like the `facter`
gem) are also installed during the image build process.

Once these dependencies have been pulled down and installed in the image that
is being built, the code for the Facter gem is modified dynamically (using the
`sed` command) so that it will detect facts from the host (rather than detecting
and reporting facts from the container that the Microkernel agent is running in)
and the code from the local copy of the Hanlon Microkernel project is added to
the image. All of this is accomplished using a Docker file that looks something
like this:

```
FROM gliderlabs/alpine

# Install any dependencies needed
RUN apk update && \
    apk add bash sed dmidecode ruby ruby-irb open-lldp util-linux open-vm-tools sudo && \
    apk add lshw ipmitool --update-cache --repository http://dl-3.alpinelinux.org/alpine/edge/testing/ --allow-untrusted && \
    echo "install: --no-rdoc --no-ri" > /etc/gemrc && \
    gem install facter json_pure daemons && \
    find /usr/lib/ruby/gems/2.2.0/gems/facter-2.4.4 -type f -exec sed -i 's:/proc/:/host-proc/:g' {} + && \
    find /usr/lib/ruby/gems/2.2.0/gems/facter-2.4.4 -type f -exec sed -i 's:/dev/:/host-dev/:g' {} + && \
    find /usr/lib/ruby/gems/2.2.0/gems/facter-2.4.4 -type f -exec sed -i 's:/host-dev/null:/dev/null:g' {} + && \
    find /usr/lib/ruby/gems/2.2.0/gems/facter-2.4.4 -type f -exec sed -i 's:/sys/:/host-sys/:g' {} +
ADD hnl_mk*.rb /usr/local/bin/
ADD hanlon_microkernel/*.rb /usr/local/lib/ruby/hanlon_microkernel/
```
To help those unfamiliar with the structure of Dockerfiles, we thought we
would break down this file into sections and discuss each of those sections
individually.

The first line of this file uses the `FROM` command to state that our
Microkernel container will be based on the standard Alpine Linux container
from GliderLabs:
```
FROM gliderlabs/alpine
```
After that line, the next section of the file uses the `RUN` command to
execute a series of the `apk` and `gem install` commands that install the
packages needed to satisfy the dependencies for our Microkernel agent code:
```
RUN apk update && \
    apk add bash sed dmidecode ruby ruby-irb open-lldp util-linux open-vm-tools sudo && \
    apk add lshw ipmitool --update-cache --repository http://dl-3.alpinelinux.org/alpine/edge/testing/ --allow-untrusted && \
    echo "install: --no-rdoc --no-ri" > /etc/gemrc && \
    gem install facter json_pure daemons && \
```
In this section of the Dockerfile, the bash, sed, dmidecode, ruby, ruby-irb,
open-lldp, util-linux (which contains the lscpu command), and open-vm-tools
packages are installed from the 'main' Alpine Linux package repository and the
lshw and ipmitool packages are installed from the 'testing' repository (since
they are not yet available in the 'main' repository). The last two lines
of this section setup the `gem` command so that it will not install
documentation by default and install the `facter`, `json_pure`, and `daemons`
RubyGems (which are required by the Microkernel controller codebase).

Now that we have installed the packages containing our dependencies, the
last section of our Dockerfile is used to modify the facter gem that was
installed previously so that it looks for system-related information
in a different location that it would typically look. These modifications
are made using a series of find/sed commands:
```
find /usr/lib/ruby/gems/2.2.0/gems/facter-2.4.4 -type f -exec sed -i 's:/proc/:/host-proc/:g' {} + && \
find /usr/lib/ruby/gems/2.2.0/gems/facter-2.4.4 -type f -exec sed -i 's:/dev/:/host-dev/:g' {} + && \
find /usr/lib/ruby/gems/2.2.0/gems/facter-2.4.4 -type f -exec sed -i 's:/host-dev/null:/dev/null:g' {} + && \
find /usr/lib/ruby/gems/2.2.0/gems/facter-2.4.4 -type f -exec sed -i 's:/sys/:/host-sys/:g' {} +
```
In the first, second, and fourth lines of this snippet you can see that the
`/proc/`, `/dev/`, and `/sys/` strings (all of these are absolute paths to files
in the `/proc`, `/dev`, and `/sys` filesystems in what will be the Microkernel
container) are replaced with the strings `/host-proc/`, `/host-dev/`, and
`/host-sys/`, respectively. The third line in this snippet just rolls back
changes that might have been made to commands that redirected to the `/dev/null`
device so that the reference remains correct in that instance.

The last sections of that Dockerfile:
```
ADD hnl_mk*.rb /usr/local/bin/
ADD hanlon_microkernel/*.rb /usr/local/lib/ruby/hanlon_microkernel/
```

Simply add files from the local copy of the Hanlon-Microkernel repository to the
Docker image that is being built. The result is a Docker image that can be run
on any platform capable of running Docker containers and that contains the
code necessary for that Docker container to act as a Hanlon-Microkernel.

## Building a new Hanlon Microkernel image

Now that we have explained how this Dockerfile works, how do you use it?
The command to build a new image using this Dockerfile is quite simple:
```
docker build -t new_mk_image:{VERSION} .
```
where the string `{VERSION}` should be replaced with the version number of the
Microkernel instance that is being built.

Once that command has been run, a new image (named 'new_mk_image') will appear
as an image within Docker (and can be used as the basis for starting new
containers using the `docker run` command). The next step in the process is to
save that image in a form that can be used to transfer the image over to a
running RancherOS instance. The easiest way to do this is via the `docker save`
command:
```
docker save new_mk_image > new_mk_image_save.tar
```
The resulting tarfile can then be gzipped (using the `gzip` command) or bzipped
(using the `bzip2` command) if you would like to save space (or it can be left
as a regular tarfile). It can then be included as part of a Hanlon Microkernel
via the `hanlon image add -t mk ...` CLI command (or an equivalent POST to the
Hanlon server's RESTful API):
```
hanlon image add -t mk -p ~/transfer/rancheros-v0.4.1.iso -d ~/transfer/new_mk_image_save.tar.bz2 -k ~/.ssh/id_rsa.pub
```
Those familiar with the old (pre-version 3.x) version of Hanlon, will notice
that the command shown above had a few additional arguments above and beyond the
arguments that were used in older versions of Hanlon to add a new Microkernel
to the system. As was the case with previous versions of Hanlon, adding a
Microkernel to Hanlon requires that a reference to the ISO for an in-memory
OS that can be used to iPXE-boot a node (using the `-p` or `--path` argument
followed by the path the the ISO file). As was mentioned previously, the
difference here is that the Microkernel ISO that is provided must be the ISO
for a RancherOS distribution (rather than a customized version of Tiny Core
Linux). In addition, adding a Microkernel to Hanlon also requires that we
provide a path to a Microkernel (Docker image file that was constructed and
saved to a local file using the procedure outlined above. The path to this
Microkernel (Docker) image file is specified using the new `-d` or
`--docker-image` command-line flag. As was described earlier, Hanlon assumes
that the version for the Microkernel is included in the Microkernel (Docker)
image's tag, so there is no need to specify a version when adding a
Hanlon Microkernel image to Hanlon.

There is an additional flag shown in the `hanlon image add -t mk ...` command
that is shown above that sets a public key (the public part of a public/private
key pair) that can be used to log into the a node (as the user `rancher`) once
that node has booted into the Hanlon Microkernel. Another optional flag can
be used to set a password that can be used to SSH into the instance (if you'd
prefer to authenticate using a username/password instead of a public/private
key pair) and, of course, the same tasks can be accomplished through the
Hanlon RESTful API. Both of these parameters are described more fully (along
with the RESTful equivalent to the CLI command shown, above) in the
documentation for Hanlon's `image` slice in the Hanlon Wiki.

## Versioning the Microkernel based on meta-data from the local GitHub repository

As an aside, it should be noted that it the Hanlon Microkernel can be easily
tagged with a version number that reflects the version information from
the local clone of the GitHub repository directly in the `docker build ...`
command shown above.  To add a GitHub-based tag simply use a command that looks
something like this during the Microkernel (Docker) image build process:
```
docker build -t new_mk_image:`git describe --tags --dirty --always | sed -e 's@-@_@' | sed -e 's/^v//'` .
```
The `{VERSION}` string from the `docker build ...` command shown previously has
been replaced (in this example) with the embedded command pipeline:
```
git describe --tags --dirty --always | sed -e 's@-@_@' | sed -e 's/^v//'
```
This command pipeline first uses the `git describe` command to retrieve the
current version from the repository, resulting in a string that looks something
like `v2.0.1-13-g3eade33-dirty`. That string is then piped through to a `sed`
command that converts the first `-` to an `_` (so the new string looks something
like `v2.0.1_13-g3eade33-dirty`) and the result is piped to a second `sed`
command that simply strips off the leading `v` character. The result is a tag
suitable for use with a Docker image that will look something like the
following:
```
2.0.1_13-g3eade33-dirty
```
In this example, you can see that the Microkernel was built from a clone of the
Hanlon Microkernel project that is 13 commits ahead of a tag that looks like
`v2.0.1`, that the corresponding commit in the GitHub repository is commit
`g3eade33`, and that the Microkernel includes changes that have not yet been
committed to the repository (which is apparent by the `-dirty` suffix that
was added to the tag by the original `git describe` command).

## How Hanlon uses the Microkernel image

Hanlon follows a two-part strategy when booting a node using the Microkernel
instances added to it. First, Hanlon will iPXE-boot the node using the
RancherOS ISO that was used when adding the Microkernel to Hanlon. The iPXE-boot
script that is fed to that RancherOS instance includes a Hanlon URL that the
RancherOS instance should use to retrieve it's `cloud-config`. That
`cloud-config` includes a Hanlon URL that the RancherOS should use to retrieve
(and start a container using) the associated Microkernel (Docker) image file
during the boot process. During the process of starting that Microkernel
container, the Microkernel controller will also be automatically started,
causing the node to checkin and register with Hanlon.

## Interacting with a running Microkernel container

Once the Microkernel container is up and running, you can SSH into the RancherOS
image (provided your Microkernel instance allows for that level of access using
either an SSH key or a password). Once you've logged into the RancherOS instance
attaching to the running container is a simple matter of running a command like
the following:
```
docker exec -it hnl_mk /bin/bash
```
That command should present you with a command-line prompt for a new BASH
shell instance running on the `hnl_mk` container instance that is running inside
of the RancherOS instance.

Once you've attached to the `hnl_mk` container instance, there are a number of
steps that you can use to debug issues that might arise with the Hanlon
Microkernel in your own environment. Details on this are process are included
in the Hanlon-Microkernel Wiki.
