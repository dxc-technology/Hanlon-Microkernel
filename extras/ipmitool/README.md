Alpine Linux ipmitool build
===========================

The latest repos for Alpine Linux has dropped the ipmitool package. As 
as result it is necessary to build ipmitool from scratch to get the APK
package file. 

Simple Build
------------

From a host that has Docker installed simply execute the build.sh script. 
This script will create an Alpine Linux container to create a build of
ipmitool, fetch the distribution, build and create the APK package. At 
the end of the script, the APK file will be copied to the parent directory
to be included in the Hanlon-Microkernel container. 

Manual Build
------------

If you really have a special case, then you can build manually by creating
the Docker container and then executing a shell to manually build ipmitool.
The following commands will get you to the command prompt in the container:

    docker build -t ipmibuild .
    docker run -it -v $(pwd):/home/builder ipmibuild ash

