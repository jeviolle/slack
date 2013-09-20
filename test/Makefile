include ../Makefile.common

TEST_TMPDIR=$(shell pwd)/tmp
export TEST_TMPDIR

CONFFILES=slack.conf roles.conf
TARGETS=$(addprefix $(TEST_TMPDIR)/, $(CONFFILES))

all: $(TARGETS)

install install-bin install-conf install-lib install-man: all

$(TEST_TMPDIR):
	mkdir -p $(TEST_TMPDIR)

$(TEST_TMPDIR)/%.conf: %.conf.template gen_config_file $(TEST_TMPDIR)
	./gen_config_file $< $@

clean:
	rm -f $(TARGETS)
	rm -rf $(TEST_TMPDIR)

realclean: clean

distclean: clean

test: clean all
	perl -MTest::Harness -e 'runtests(<*.t>)'

check: test
