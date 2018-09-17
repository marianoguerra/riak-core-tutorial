.. Riak Core Tutorial documentation master file, created by
   sphinx-quickstart on Mon Feb 26 18:20:02 2018.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

Riak Core Tutorial
==================

Welcome to the Riak Core Tutorial, a shorter, updated version of
`The Riak Core Book <https://marianoguerra.github.io/little-riak-core-book/>`_ focused more on the implementation details, for more explanation check The Riak Core Book.

This book shows how to build an application using `riak_core <https://github.com/basho/riak_core>`_ by building an actual application called tanodb step by step and linking to each change on its the description.

Each chapter is a branch in this repo: https://gitlab.com/marianoguerra/tanodb/commits/master

The tutorial was written by Mariano Guerra, you can find him at:

* `Website <http://marianoguerra.org/>`_
* `Github <http://github.com/marianoguerra/>`_
* `Twitter <http://twitter.com/warianoguerra>`_

If you think something could be improved, report it on the `issue tracker <https://github.com/marianoguerra/riak-core-tutorial/issues>`_.

.. toctree::
   :maxdepth: 2

   setup
   starting
   ping-command
   first-command
   quorum-requests
   handoff
   coverage-calls
   http-api
   leveled-backend
