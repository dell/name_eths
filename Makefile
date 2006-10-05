  RELEASE_DATE := "05-Oct-2006"
  RELEASE_MAJOR := 0
  RELEASE_MINOR := 4
  RELEASE_EXTRALEVEL :=
  RELEASE_NAME := name_eths
  RELEASE_STRING := $(RELEASE_NAME)-$(RELEASE_MAJOR).$(RELEASE_MINOR)$(RELEASE_EXTRALEVEL)

  .PHONY: clean tarball

  clean:
	rm -f *~

  tarball: clean
	-rm $(RELEASE_NAME)*.tar.gz
	cp -a ../$(RELEASE_NAME) ../$(RELEASE_STRING)
	find ../$(RELEASE_STRING) -name CVS -type d -depth -exec rm -rf \{\} \;
	sync; sync; sync;
	cd ..; tar cvzf $(RELEASE_STRING).tar.gz $(RELEASE_STRING)
	mv ../$(RELEASE_STRING).tar.gz .
	rm -rf ../$(RELEASE_STRING)
