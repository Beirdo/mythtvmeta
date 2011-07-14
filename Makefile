DOTARGETS = all clean patch-clean patch-remove update

${DOTARGETS}:
	gmake -f Makefile.gmake do-$@ ${MAKEOPTS}

TARGETS  = nuvexport mythweb backgrounds scripts 
TARGETS += mythtv/mythtv mythtv/mythplugins myththemes

${TARGETS}:
	gmake -f Makefile.gmake $@ ${MAKEOPTS}

.PHONY: ${TARGETS}
