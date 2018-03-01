# Minimal makefile for Sphinx documentation
#

# You can set these variables from the command line.
SPHINXOPTS    =
SPHINXBUILD   = sphinx-build
SPHINXPROJ    = RiakCoreTutorial
SOURCEDIR     = source
BUILDDIR      = build

# Put it first so that "make" without argument is like "make help".
help:
	@$(SPHINXBUILD) -M help "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O)

publish: html
	cd build/ && rm -rf riak-core-tutorial.tgz && mv html riak-core-tutorial && tar -czf riak-core-tutorial.tgz riak-core-tutorial && scp riak-core-tutorial.tgz marianoguerra@marianoguerra.org:~/marianoguerra.org/tmp/ && ssh marianoguerra@marianoguerra.org "cd ~/marianoguerra.org/tmp; rm -rf riak-core-tutorial; tar -xzf riak-core-tutorial.tgz"


.PHONY: help Makefile

# Catch-all target: route all unknown targets to Sphinx using the new
# "make mode" option.  $(O) is meant as a shortcut for $(SPHINXOPTS).
%: Makefile
	@$(SPHINXBUILD) -M $@ "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O)
