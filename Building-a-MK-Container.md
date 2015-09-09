## Building a Hanlon Microkernel image

Our new Microkernel Docker Image will be based on the standard Alpine Linux
container, since this container provides is with a platform that is small
(an important consideration) and includes packages that we can use to satisfy
the dependencies for our Microkernel agent code (ruby, ipmitool, dmidecode,
lshw, lscpu, facter, and the open-lldp and open-vm-tools packages).

The first step in this process, then, is to define a Dockerfile that we can use
to build such a container. Here is what the current Dockerfile looks like:
```
FROM gliderlabs/alpine

# Install any dependencies needed
RUN apk update && \
  apk add bash dmidecode ruby open-lldp util-linux open-vm-tools && \
  apk add lshw ipmitool --update-cache --repository http://dl-3.alpinelinux.org/alpine/edge/testing/ --allow-untrusted && \
  echo "install: --no-rdoc --no-ri" > /etc/gemrc && \
  gem install facter && \
  find /usr/lib/ruby/gems/2.2.0/gems/facter-2.4.4 -type f -exec sed -i 's:/proc/:/host-proc/:g' {} + && \
  find /usr/lib/ruby/gems/2.2.0/gems/facter-2.4.4 -type f -exec sed -i 's:/dev/:/host-dev/:g' {} + && \
  find /usr/lib/ruby/gems/2.2.0/gems/facter-2.4.4 -type f -exec sed -i 's:/host-dev/null:/dev/null:g' {} + && \
  find /usr/lib/ruby/gems/2.2.0/gems/facter-2.4.4 -type f -exec sed -i 's:/sys/:/host-sys/:g' {} +
```
To help those unfamiliar with the structure of Dockerfiles, we thought we
would break down this file into sections and discuss each of those sections
individually.

The first line of this file uses the `FROM` command to state that our
Microkernel container will be based on the standard Apline Linux container
from GliderLabs:
```
FROM gliderlabs/alpine
```
After that line, the next section of the file uses the `RUN` command to
execute a series of the `apk` and `gem install` commands that install the
packages needed to satisfy the dependencies for our Microkernel agent code:
```
RUN apk update && \
  apk add bash dmidecode ruby open-lldp util-linux open-vm-tools && \
  apk add lshw ipmitool --update-cache --repository http://dl-3.alpinelinux.org/alpine/edge/testing/ --allow-untrusted && \
  echo "install: --no-rdoc --no-ri" > /etc/gemrc && \
  gem install facter && \
```
In this section of the Dockerfile, the bash, dmidecode, ruby, open-lldp,
util-linux (which contains the lscpu command), and open-vm-tools packages
are installed from the 'main' Alpine Linux package repository and the lshw
and ipmitool packages are installed from the 'testing' repository (since
they are not yet available in the 'main' repository). The last two lines
of this section setup the `gem` command so that it will not install
documentation by default and install the `facter` gem (which is used
by our Microkernel agent code to obtain facts about the underlying system).

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
'/proc/', '/dev/', and '/sys/' strings (all of these are absolute paths to files
in the '/proc', '/dev', and '/sys' filesystems) are replaced with the strings
'/host-proc/', '/host-dev/', and '/host-sys/', respectively. The third line in
this snippet just rolls back changes that might have been made to commands that
redirected to the '/dev/null' device so that the reference remains correct in
that instance.

Now that we have explained how this Dockerfile works, how do you use it?
The command to build a new image using this Dockerfile is quite simple:
```
docker build -t new_mk_image .
```
Once that command is run, a new image (named 'new_mk_image') will appear as
an image within Docker (and can be used as the basis for starting new
containers using the `docker run` command).

## Running our new image as a container under CoreOS

Once our image is built, we next need to save it into a form that can be
transferred over to a running CoreOS instance
```
docker save new_mk_image > new_mk_image_save.tar
cp new_mk_image_save.tar ~/src/transfer/coreos-files/
```
While we are at it, we should also copy over the 'service' file we have defined
here for our Hanlon Microkernel service to the same directory:
```
cp hnl.service ~/src/transfer/coreos-files/
```
Now that we have our new container image and service files together in the
same directory, we can copy those files over to a CoreOS instance and run
our Hanlon Microkernel container locally using the `fleetctl` command:
```
scp -r root@192.168.78.2:./transfer/coreos-files .
sudo systemctl start etcd.service
sudo systemctl start fleet.service
fleetctl load coreos-files/hnl.service
fleetctl start hnl.service
```
Once the container is up and running, you can attach to it using a command
like the following:
```
docker exec -i -t hnl_mk /bin/bash
```
That command should present you with a command-line prompt for a new BASH
shell instance running on the 'hnl_mk' container instance that was started
up using the `fleetctl` command, above.

## A brief discussion of 'service' files

As you can see, the `fleetctl load` command that we ran, above, takes an
additional command-line argument. That argument is a reference a 'service' file
that defines how our new container should be run. In this case, the
`hnl.service` file we are using looks like this:
```
[Unit]
Description=HanlonMicrokernel
After=docker.service
Requires=docker.service

[Service]
TimeoutStartSec=0
KillMode=none
ExecStartPre=-/usr/bin/docker rmi new_mk_image
ExecStartPre=/usr/bin/docker load -i /home/core/coreos-files/new_mk_image_save.tar
ExecStart=/usr/bin/docker run --privileged=true --name=hnl_mk -v /proc:/host-proc:ro -v /dev:/host-dev:ro -v /sys:/host-sys:ro --net host -t new_mk_image /bin/bash
ExecStop=/usr/bin/docker stop hnl_mk
ExecStopPost=/usr/bin/docker kill hnl_mk
ExecStopPost=/usr/bin/docker rm hnl_mk
ExecStopPost=/usr/bin/docker rmi new_mk_image

[X-Fleet]
X-Conflicts=hnl.service
```
For now, the important lines to look at are the following two lines:
```
ExecStartPre=/usr/bin/docker load -i /home/core/coreos-files/new_mk_image_save.tar
ExecStart=/usr/bin/docker run --privileged=true --name=hnl_mk -v /proc:/host-proc:ro -v /dev:/host-dev:ro -v /sys:/host-sys:ro --net host -t new_mk_image /bin/bash
```
the first line in this snippet loads the image file we saved (and copied over,
above) into Docker, while the second one starts up an instance of that image as
a container. Note that the docker command in the second line runs that container
in both 'privileged' mode and 'host' networking mode. This is critical to
successfully running our Microkernel agent code within this container. We run
the container in privileged mode to ensure that the resources from the
underlying CoreOS host will be visible to our container, and we running the
container in host networking mode so that the network from the CoreOS host will
be visible to the container as well (without it, our Microkernel would not be
able to see the network devices detected by the CoreOS host).

One final note on the docker command used here. As you can quite clearly see, we
map the '/proc', '/dev' and '/sys' filesystems from our CoreOS host into the
'/host-proc', '/host-dev' and '/host-sys' filesystems in our new container.
As you may recall, these correspond to the paths we used when we modified the
`facter` codebase when we built the image that this container is based on.
As a result, the `facter` command will return facts from the CoreOS host rather
than returning facts related to the local container. Whether or not we will be
able to use tools like LLPD and ipmitool to explore the CoreOS host environment
as easily (to get neighbors and ports using LLDP or to get BMC-related facts
using ipmitool) remains to be seen.
