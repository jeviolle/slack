# Makefile for slack
# $Id: Makefile 188 2008-04-21 00:42:43Z sundell $

include	Makefile.common

TARGETS = all test \
    install install-bin install-conf install-lib install-man \
    clean distclean realclean
SUBDIRS = doc src test

distdir = $(PACKAGE)-$(VERSION)


$(TARGETS)::
	@set -e; \
	 for i in $(SUBDIRS); do $(MAKE) -C $$i $@ ; done

deb:
	dpkg-buildpackage -b -uc -tc -rfakeroot
	ls -l ../slack_*_all.deb

dist: distclean
	mkdir -p ../$(distdir)
	rsync -a --exclude=.svn --exclude='*.swp' --delete-excluded \
	    . ../$(distdir)/
	chmod -R a+rX ../$(distdir)
	cd .. ; \
	    tar -cp --exclude=debian -f $(distdir).tar $(distdir) ; \
	    tar -cp -f $(distdir)-debian.tar $(distdir)/debian
	rm -rf ../$(distdir)
	gzip -9f ../$(distdir).tar ../$(distdir)-debian.tar
	chmod a+r ../$(distdir).tar.gz ../$(distdir)-debian.tar.gz
	@ls -l ../$(distdir).tar.gz ../$(distdir)-debian.tar.gz

check: test
