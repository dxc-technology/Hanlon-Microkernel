## Project Occam-Microkernel

This is part of [Project Occam][occam] - the Microkernel is the in-memory
Linux instance used to discover the hardware details and initiate
provisioning operations.

You can find more information about Occam in general, as well as ways to get
help, over at the [Occam project on GitHub][occam].  That includes the
contributing guide, and the official list of committers to the project.

[occam]: https://github.com/csc/occam


## Project Description

This project contains the Ruby scripts/classes that are used to control the Occam Microkernel (and that interact with the Occam server) along with a set of scripts and files that are needed during the Microkernel boot and initialization proces. The files contained in this project are all bundled into the current version of the Occam Microkernel (v0.9.0.1). There are three primary services that are included in this project that are started up during the Microkernel boot process. Those services include:

1. The **Occam Microkernel Controller**, which is actually contained in the ocm_mk_control_server.rb file (which is, in turn, started up and controlled using the "Ruby Daemons" interface defined in the ocm_mk_controller.rb file)
1. The **Occam Microkernel Web Server**, which can be found in the ocm_mk_web_server.rb file and which is used (by the Occam Microkernel Controller) to save configuration changes from the Occam Server to the 'local filesystem' (remember, everything is in memory). During this process of saving the configuration changes, the Microkernel Web Server will actually restart the Occam Microkernel instance (in order to force it to pick up the newly saved Microkernel configuration).
1. The **Local TCE Mirror**, which is actually contained in the ocm_mk_tce_mirror.rb file and which is used to install a few extensions during the post-boot configuration process.

If the Occam Microkernel that is being built/used is a development kernel, a fifth service will also be started during the boot process (the **OpenSSH server daemon**). That service is not started in a production system in order to prevent unauthorized access to the underlying hardware through the Occam Microkernel (in fact, the openssh.tcz extension is not even installed on these production systems).

In addition, this project also includes a number of additional ruby files and configuration files that are used by these services, a list of gems that are installed dynamically each time that the Microkernel boots (under the opt/gems directory), a copy of the 'bootsync.sh' script (under the opt directory in this project), and the 'ocm_mk_init.rb' script itself (which is used by that bootsync.sh script to start the appropriate Ruby-based services during the Microkernel boot process).

Copies of the ruby scripts that appear at the top-level of this project's directory structure can be found in the /usr/local/bin directory of the Microkernel. In addition, the files that appear in the occam_microkernel subdirectory of this project are all part of the OccamMicrokernel module, and those files are placed in the /usr/local/lib/ruby/1.8 directory in the Microkernel ISO.

It should be noted that this project also includes a set of scripts that are meant to be used to build a new instance of the Microkernel ISO. Instructions for building a new ISO instance using these scripts can be found in this project's Wiki. There are also a number of extensions to the standard Tiny Core Linux ISO that are bundled into the Occam Microkernel which are not included in this project. These extensions (and the other dependencies that are needed within the Occam Microkernel ISO that are not part of this project) are all downloaded dynamically when the Microkernel ISO is being built. Once again, instructions for building your own (custom) Microkernel ISO can be found in the project's Wiki.
