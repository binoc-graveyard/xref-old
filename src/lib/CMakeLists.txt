build_macro_mkPaths()
FIND_FINAL_TARGET()

set(PERL_SRCS
    ${mk_srcdir}/SimpleParse.pm
)

set(SOURCE_FILES
    ${PERL_SRCS}
)

COPY_TO_DIST("${SOURCE_FILES}")

add_subdirectory(LXR)