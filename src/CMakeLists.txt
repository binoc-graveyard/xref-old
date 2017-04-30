build_macro_mkPaths()
FIND_FINAL_TARGET()

set(CGI_SRCS
    ${mk_srcdir}/index.cgi
    ${mk_srcdir}/diff
    ${mk_srcdir}/find
    ${mk_srcdir}/ident
    ${mk_srcdir}/search
    ${mk_srcdir}/source
    
)

set(PERL_SRCS
    ${mk_srcdir}/update-search.pl
    ${mk_srcdir}/update-xref.pl
    ${mk_srcdir}/Local.pm
    ${mk_srcdir}/genxref
)

set(HTML_SRCS
    ${mk_srcdir}/search-help.html
)

Set(MISC_SRCS
    ${mk_srcdir}/index.php
    ${mk_srcdir}/root-index.inc
    ${mk_srcdir}/robots.txt
    ${mk_srcdir}/mxr.png
    ${mk_srcdir}/xref-update.py
)

set(SOURCE_FILES
    ${CGI_SRCS}
    ${PERL_SRCS}
    ${HTML_SRCS}
    ${MISC_SRCS}
)

build_func_preprocess(
    xref-conf.py.in
    ${FINAL_TARGET}/xref-conf.py
    ${varBuildDefines}
    --marker %
    --make-exec
)

COPY_TO_DIST("${SOURCE_FILES}")

add_subdirectory(lib)
add_subdirectory(media)