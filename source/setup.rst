Setup
=====

We first need to have Erlang installed and rebar3 installed.

Setting up kerl
---------------

To install Erlang we will use `kerl <https://github.com/kerl/kerl>`_, from its github README::

    Easy building and installing of Erlang/OTP instances.

    Kerl aims to be shell agnostic and its only dependencies, excluding what's
    required to actually build Erlang/OTP, are curl and git.

So, first we need to fetch kerl:

.. code:: sh

    # create bin folder in our home directory if it's not already there
    mkdir -p ~/bin

    # cd to it
    cd ~/bin

    # download kerl script
    curl -O https://raw.githubusercontent.com/kerl/kerl/master/kerl

    # set execution permitions for our user
    chmod u+x kerl

You will need to add ~/bin to your PATH variable so your shell can find the
kerl script, you can do it like this in your shell:

.. code:: sh

    # set the PATH environment variable to the value it had before plus a colon
    # (path separator) and a new path which points to the bin folder we just
    # created
    PATH=$PATH:$HOME/bin

If you want to make this work every time you start a shell you need to put it
it the rc file of your shell of choice, for bash it's ~/.bashrc, for zsh it's
~/.zshrc, you will have to add a line like this:

.. code:: sh

    export PATH=$PATH:$HOME/bin

After this, start a new shell or source your rc file so that it picks up your
new PATH variable, you can check that it's set correctly by running:

.. code:: sh

    echo $PATH

And checking in the output if $HOME/bin is there (notice that $HOME will be
expanded to the actual path).

Building an Erlang release with kerl
------------------------------------

We have kerl installed and available in our shell, now we need to build an
Erlang release of our choice, for this we will need a compiler and other
tools and libraries needed to compile it:

This are instructions on ubuntu 17.10, check the names for those packages
on your distribution.

.. code:: sh

    # required: basic tools and libraries needed
    # (compiler, curses for the shell, ssl for crypto)
    sudo apt-get -y install build-essential m4 libncurses5-dev libssl-dev

    # optonal: if you want odbc support (database connectivity)
    sudo apt-get install unixodbc-dev

    # optonal: if you want pdf docs you need apache fop and xslt tools and java (fop is a java project)
    sudo apt-get install -y fop xsltproc default-jdk

    # optional: if you want to build jinterface you need a JDK
    sudo apt-get install -y default-jdk

    # optional: if you want wx (desktop GUI modules)
    sudo apt-get install -y libwxgtk3.0-dev

Now that we have everything we need we can finally build our Erlang release.

First we fetch an updated list of releases:

.. code:: sh

    kerl update releases

The output in my case::

    The available releases are:

    R10B-0 R10B-10 R10B-1a R10B-2 R10B-3 R10B-4 R10B-5 R10B-6 R10B-7 R10B-8
    R10B-9 R11B-0 R11B-1 R11B-2 R11B-3 R11B-4 R11B-5 R12B-0 R12B-1 R12B-2 R12B-3
    R12B-4 R12B-5 R13A R13B01 R13B02-1 R13B02 R13B03 R13B04 R13B R14A R14B01
    R14B02 R14B03 R14B04 R14B_erts-5.8.1.1 R14B R15B01 R15B02
    R15B02_with_MSVCR100_installer_fix R15B03-1 R15B03 R15B
    R16A_RELEASE_CANDIDATE R16B01 R16B02 R16B03-1 R16B03 R16B 17.0-rc1 17.0-rc2
    17.0 17.1 17.3 17.4 17.5 18.0 18.1 18.2.1 18.2 18.3 19.0 19.1 19.2 19.3
    20.0 20.1 20.2

Let's build the 20.1 version:

.. code:: sh

    # this will take a while
    kerl build 20.2 20.2

And install it:

.. code:: sh

   kerl install 20.2 ~/bin/erl-20.2

Now everytime we want to use this version of Erlang we need to run:

.. code:: sh

    . $HOME/bin/erl-20.2/activate

Setting up rebar3
-----------------

Now we have Erlang, we need a build tool, we are going to use `rebar3 <http://rebar3.org>`_:

.. code:: sh

    # download rebar3 to our bin directory
    wget https://s3.amazonaws.com/rebar3/rebar3 -O $HOME/bin/rebar3

    # set execution permissions for our user
    chmod u+x rebar3

Just in case you have problems running the rebar3 commands with a different
version, here's the version I'm using:

.. code:: sh

    rebar3 version

Output::

    rebar 3.5.0 on Erlang/OTP 20 Erts 9.2

Install Riak Core Rebar3 Template
---------------------------------

To create a Riak Core project from scratch we will use a template called `rebar3_template_riak_core <https://github.com/marianoguerra/rebar3_template_riak_core/>`_.

we need to clone its repo in a place where rebar3 can see it:

.. code:: sh

    mkdir -p ~/.config/rebar3/templates
    git clone https://github.com/marianoguerra/rebar3_template_riak_core.git ~/.config/rebar3/templates/rebar3_template_riak_core

Test that Everything Works
--------------------------

We have installed several tools:

kerl
    Let's you install multiple Erlang releases that can live side by side
Erlang 20.2
    The version of erlang we are going to be using
Rebar 3
    Our build tool
rebar3_template_riak_core
    Rebar 3 Template that will make it easy to setup fresh riak_core projects
    for experimentation

Now we need to check that everything is setup correctly, we will do that by
creating a template and building it.

Remember to have $HOME/bin in your $PATH and Erlang 20.2 activated, `cd` to a folder of your choice to hold this project and run:

.. code:: sh

    rebar3 new rebar3_riak_core name=akv

Output should be similar to this one::

    ===> Writing akv/apps/akv/src/akv.app.src
    ===> Writing akv/apps/akv/src/akv.erl
    ===> Writing akv/apps/akv/src/akv_app.erl
    ===> Writing akv/apps/akv/src/akv_sup.erl
    ===> Writing akv/apps/akv/src/akv_console.erl
    ===> Writing akv/apps/akv/src/akv_vnode.erl
    ===> Writing akv/rebar.config
    ===> Writing akv/.editorconfig
    ===> Writing akv/.gitignore
    ===> Writing akv/README.rst
    ===> Writing akv/Makefile
    ===> Writing akv/config/admin_bin
    ===> Writing akv/priv/01-akv.schema
    ===> Writing akv/config/advanced.config
    ===> Writing akv/config/vars.config
    ===> Writing akv/config/vars_dev1.config
    ===> Writing akv/config/vars_dev2.config
    ===> Writing akv/config/vars_dev3.config


Now let's try to build it:

.. code:: sh

    cd akv
    make

Output is to long to list, after it ends, near the end you should see this line::

    ===> release successfully created!

Now let's try to run it:
    
.. code:: sh

    make console

Last lines should be::

    Eshell V9.2  (abort with ^G)
    (akv@127.0.0.1)1>

You can exit with `q().` and pressing enter or hitting Ctrl-C twice.

We're ready to start!

