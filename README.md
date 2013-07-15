# The road forward for Razor

During it's fairly short lifespan so far, Razor has shown that there
is considerable demand for a policy-driven provisioning tool based on
discovery of nodes. The thriving, and growing, community, and the fact
that other tools are adopting Razor's approach are ample proof of
that.

Over the last year, we've also learned a lot about the community's
needs and how Razor should evolve, and about the limitations of Razor
that make evolution harder than it needs to be. This knowledge has
brought us to the conclusion that Razor's community and future
development are best served by a rewrite of the current code base. The
rewrite will carry the important and unique features of Razor forward,
such as node discovery via a Microkernel, provisioning based off
tagging nodes and policy, and flexibility in controlling the
provisioning process. It will also change the code base in a way that
we feel makes Razor more supportable and maintainable.

The rewrite will reach a state where the rewritten Razor is pretty
much feature-equivalent with the current implementation by the end of
August (puppetconf, really).

Overview

The cornerstones of the Razor rewrite are:

 * it will be based on widely adopted and well-understood web
technologies: it will be written entirely in Ruby using Sinatra as the
web framework, Sequel as the ORM layer, and PostgreSQL as the
database. Among other things, this makes it possible to use
associations in the object model, and provide transactional guarantees
around complex operations.

 * tagging will be controlled by a simple query language; this makes
it possible to assign tags using fairly complicated logical
expressions using and, or, comparison operators, or even checks
whether a fact is included in a fixed list (e.g., to associate a tag
with a fixed list of MAC addresses)
the current system of models will be greatly simplified, and models
can be described entirely in metadata, without needing to write Ruby
code (see below)

 * RESTful API's to query existing objects; command-oriented API to
control the provisioning setup; authentication for all the API's
(except for the server/node communication, which is pretty much
impossible to secure); separate URL structures for the management and
node/server API to make it easier to restrict those separately

 * the Razor-specific microkernel functionality will be broken out
more clearly from the underlying substrate, making it easier to
experiment with alternative microkernels

 * the main microkernel will be based off RHEL/CentOS to provide an
easy way for users to do hardware discovery with a kernel that is
known and certified to work on their hardware

 * since Razor controls the node during installation, broker handoff
should be driven off the node, supported by stock broker scripts that
ship with Razor

Controlling installation

Currently, installation is controlled by models, which consist of a
state machine, file templates, and some helper code for those
templates. The same functionality can be provided by a simpler
approach: the only place where (server-side) state matters during
installation is in determining how to respond to repeated reboot
requests from the node - usually, the sequence is 'boot installler on
the first boot after policy is bound, boot locally afterwards'.

Everything else that happens during installation falls into three categories:

* retrieve a file; the file is the result of interpolating a specific
template (e.g., kickstart file, post install script etc.)
* log a message and associate it with the node
* report node-specific data (really only its IP address) back to the server

All three of these are easily done on the server-side by a standard
web application.

An installer (i.e., what used to be called a model) then really
consists of two ingredients: (1) a metadata description that contains
things like name, os name and version, as well as instructions on how
to respond to repeated boot requests (2) a number of ERB templates
that the node can request during the installation process.

This will make adding custom installers very easy, and allow for
adding them entirely through the API.

Status

We've started a strawman of the reimplementation; most of the work has
gone into the server side so far. The current state of affairs can be
found on github:

https://github.com/puppetlabs/razor-server
https://github.com/puppetlabs/razor-el-mk

We'd love to hear your feedback, and hope to see both lots of
discussion and patches to continue to make Razor the best provisioning
tool out there.

David Lutterkert, and Daniel Pittman
