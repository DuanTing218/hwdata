NAME=$(shell awk '/Name:/ { print $$2 }' hwdata.spec)
VERSION=$(shell awk '/Version:/ { print $$2 }' hwdata.spec)
RELEASE=$(shell awk '/Release:/ { a=$$2; sub("%.*","",a); print a }' hwdata.spec)
SOURCEDIR := $(shell pwd)

prefix=$(DESTDIR)/usr
sysconfdir=$(DESTDIR)/etc
bindir=$(prefix)/bin
sbindir=$(prefix)/sbin
datadir=$(prefix)/share
mandir=$(datadir)/man
includedir=$(prefix)/include
libdir=$(prefix)/lib

CC=gcc
CFLAGS=$(RPM_OPT_FLAGS) -g

CVSROOT = $(shell cat CVS/Root 2>/dev/null || :)

CVSTAG = $(NAME)-r$(subst .,-,$(VERSION))

FILES = CardMonitorCombos Cards MonitorsDB pci.ids pcitable upgradelist usb.ids

.PHONY: all install tag force-tag check create-archive archive srpm-x clean clog new-pci-ids new-usb-ids

all: 

install:
	mkdir -p -m 755 $(datadir)/$(NAME)
	for foo in $(FILES) ; do \
		install -m 644 $$foo $(datadir)/$(NAME) ;\
	done
	mkdir -p -m 755 $(datadir)/$(NAME)/videoaliases
	mkdir -p -m 755 $(prefix)/X11R6/lib/X11
	ln -s ../../../share/$(NAME)/Cards $(prefix)/X11R6/lib/X11/Cards
	mkdir -p -m 755 $(sysconfdir)/pcmcia
	install -m 644 config $(sysconfdir)/pcmcia
	mkdir -p -m 755 $(sysconfdir)/hotplug/
	install -m 644 blacklist $(sysconfdir)/hotplug/

tag:
	@git tag -a -m "Tag as $(NAME)-$(VERSION)-$(RELEASE)" $(NAME)-$(VERSION)-$(RELEASE)
	@echo "Tagged as $(NAME)-$(VERSION)-$(RELEASE)"

force-tag:
	@git tag -f $(NAME)-$(VERSION)-$(RELEASE)
	@echo "Tag forced as $(NAME)-$(VERSION)-$(RELEASE)"

changelog:
	@rm -f ChangeLog
	@(GIT_DIR=.git git-log > .changelog.tmp && mv .changelog.tmp ChangeLog || rm -f .changelog.tmp) || (touch ChangeLog; echo 'git directory not found: installing possibly empty changelog.' >&2)

check:
	[ -x /sbin/lspci ] && /sbin/lspci -i pci.ids > /dev/null
	./check-pci-ids.py
	@: videodrivers is tab-separated
	[ `grep -vc '	' videodrivers` -eq 0 ]

create-archive:
	@rm -rf $(NAME)-$(VERSION) $(NAME)-$(VERSION).tar*  2>/dev/null
	@make changelog
	@git-archive --format=tar --prefix=$(NAME)-$(VERSION)/ HEAD > $(NAME)-$(VERSION).tar
	@mkdir $(NAME)-$(VERSION)
	@cp ChangeLog $(NAME)-$(VERSION)/
	@tar --append -f $(NAME)-$(VERSION).tar $(NAME)-$(VERSION)
	@bzip2 -f $(NAME)-$(VERSION).tar
	@rm -rf $(NAME)-$(VERSION)
	@echo ""
	@echo "The final archive is in $(NAME)-$(VERSION).tar.bz2"

archive: check clean tag create-archive

dummy:

srpm-x: create-archive
	@echo Creating $(NAME) src.rpm
	@rpmbuild --nodeps -bs --define "_sourcedir $(SOURCEDIR)" --define "_srcrpmdir $(SOURCEDIR)" $(NAME).spec
	@echo SRPM is: $(NAME)-$(VERSION)-$(RELEASE).src.rpm

clean:
	@rm -f $(NAME)-*.gz $(NAME)-*.src.rpm

clog: hwdata.spec
	@sed -n '/^%changelog/,/^$$/{/^%/d;/^$$/d;s/%%/%/g;p}' $< | tee $@

new-usb-ids:
	@curl -O http://www.linux-usb.org/usb.ids

new-pci-ids:
	@curl -O http://pciids.sourceforge.net/pci.ids
