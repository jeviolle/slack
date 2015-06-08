# Makefile for slack/src
# $Id: Makefile 187 2008-03-03 02:00:18Z alan $
include ../Makefile.common

BACKENDS = slack-getroles slack-installfiles slack-runscript slack-sync slack-stage slack-rolediff

all:

install: install-bin install-conf install-lib install-man

install-bin: all
	$(MKDIR) $(DESTDIR)$(sbindir)
	$(INSTALL) slack $(DESTDIR)$(sbindir)
	$(MKDIR) $(DESTDIR)$(bindir)
	$(INSTALL) slack-diff $(DESTDIR)$(bindir)
	$(MKDIR) $(DESTDIR)$(slack_libexecdir)
	@set -ex;\
	for i in $(BACKENDS); do \
	$(INSTALL) $$i $(DESTDIR)$(slack_libexecdir); done
	$(INSTALL) -d -m $(PRIVDIRMODE) $(DESTDIR)$(slack_localstatedir)
	$(INSTALL) -d -m $(PRIVDIRMODE) $(DESTDIR)$(slack_localcachedir)

install-conf: all
	$(MKDIR) $(DESTDIR)$(sysconfdir)
	$(INSTALL) -m 0644 slack.conf $(DESTDIR)$(sysconfdir)
	$(INSTALL) -m 0644 slackignore $(DESTDIR)$(sysconfdir)

install-lib: all
	$(MKDIR) $(DESTDIR)$(slack_libdir)
	$(INSTALL) -m 0644 Slack.pm $(DESTDIR)$(slack_libdir)

install-man: all

clean:

realclean: clean

distclean: clean

test:
