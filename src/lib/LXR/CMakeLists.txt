build_macro_mkPaths()
FIND_FINAL_TARGET()

set(PERL_SRCS
    ${mk_srcdir}/Common.pm
    ${mk_srcdir}/Config.pm
    ${mk_srcdir}/Shell.pm
)

set(SOURCE_FILES
    ${PERL_SRCS}
)

COPY_TO_DIST("${SOURCE_FILES}")