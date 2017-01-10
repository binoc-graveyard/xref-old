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

set(BINARY_SRCS
    ${mk_srcdir}/fileidx
    ${mk_srcdir}/xref
)

set(JS_SRCS
    ${mk_srcdir}/coloration.js
    ${mk_srcdir}/jquery-1.3.2.min.js
    ${mk_srcdir}/script.js
)

set(HTML_SRCS
    ${mk_srcdir}/index.html
    ${mk_srcdir}/search-help.html
)

Set(MISC_SRCS
    ${mk_srcdir}/.htaccess
    ${mk_srcdir}/robots.txt
    ${mk_srcdir}/lxr.conf
    ${mk_srcdir}/mxr.png
)

set(SOURCE_FILES
    ${CGI_SRCS}
    ${PERL_SRCS}
    ${BINARY_SRCS}
    ${JS_SRCS}
    ${HTML_SRCS}
    ${MISC_SRCS}
)

COPY_TO_DIST("${SOURCE_FILES}")

add_subdirectory(icons)
add_subdirectory(lib)
add_subdirectory(root)
add_subdirectory(style)
add_subdirectory(templates)