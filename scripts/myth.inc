function get_prefix () {
    PROGNAME=`echo $0 | sed -e 's/^.*\///'`
    BRANCH=$1

    if [ .${BRANCH}. != .. ] ; then 
        shift
    fi

    if [ .${BRANCH}. = .. -o .${BRANCH}. = .-. ] ; then
        BRANCH=`cat /home/gjhurlbu/.default-branch`
    fi

    if [ .${BRANCH}. = .. ] ; then
        PREFIX=/usr/local
        LOGPATH=/opt/mythtv/logs/notag
    else
        PREFIX=/opt/mythtv/${BRANCH}
        LOGPATH=/opt/mythtv/logs/${BRANCH}
    fi
    VALLOG=${LOGPATH}/valgrind-${PROGNAME}.log

    ARGS="${ARGS} $*"

    echo Program: ${PROGNAME}
    echo using prefix ${PREFIX}
    echo using arguments ${ARGS}
    echo using logpath ${LOGPATH}

    mkdir -p ${LOGPATH}

    PYTHONPATH=${PREFIX}/lib/python2.6/site-packages
    PERL5LIB=${PREFIX}/share/perl/5.10.1
    LD_LIBRARY_PATH=${PREFIX}/lib 
    PATH=${PREFIX}/bin:${PATH}
    LC_ALL=en_US.UTF-8
    QT_FATAL_WARNINGS=1
    MALLOC_CHECK_=1

    export PYTHONPATH
    export PERL5LIB
    export LD_LIBRARY_PATH
    export PATH
    export LC_ALL
    export QT_FATAL_WARNINGS
    export MALLOC_CHECK_

    export PREFIX
    export ARGS
    export LOG
    export VALLOG

    if [ .${DISPLAY}. = .. ] ; then
        DISPLAY=:0.0
        export DISPLAY
    fi

    ulimit -c 10000000
}

function get_prefix2 () {
    BRANCH=$1

    if [ .${BRANCH}. != .. ] ; then 
        shift
    fi

    if [ .${BRANCH}. = .. -o .${BRANCH}. = .-. ] ; then
        BRANCH=`cat /home/gjhurlbu/.default-branch`
    fi

    if [ .${BRANCH}. = .. ] ; then
        PREFIX=/usr/local
        LOGPATH=/opt/mythtv/logs/notag
    else
        PREFIX=/opt/mythtv/${BRANCH}
        LOGPATH=/opt/mythtv/logs/${BRANCH}
    fi

    PROGNAME=`echo $1 | sed -e 's/^.*\///'`
    if [ .${PROGNAME}. == .. ] ; then
	echo "Usage: myth branch program args"
        exit 1
    fi
    VALLOG=${LOGPATH}/valgrind-${PROGNAME}.log

    shift
    ARGS="${ARGS} $*"

    echo Program: ${PROGNAME}
    echo using prefix ${PREFIX}
    echo using arguments ${ARGS}
    echo using logpath ${LOGPATH}

    mkdir -p ${LOGPATH}

    PYTHONPATH=${PREFIX}/lib/python2.6/site-packages
    PERL5LIB=${PREFIX}/share/perl/5.10.1
    LD_LIBRARY_PATH=${PREFIX}/lib 
    PATH=${PREFIX}/bin:${PATH}
    LC_ALL=en_US.UTF-8
    QT_FATAL_WARNINGS=1
    MALLOC_CHECK_=1

    export PYTHONPATH
    export PERL5LIB
    export LD_LIBRARY_PATH
    export PATH
    export LC_ALL
    export QT_FATAL_WARNINGS
    export MALLOC_CHECK_

    export PREFIX
    export ARGS
    export LOG
    export VALLOG

    if [ .${DISPLAY}. = .. ] ; then
        DISPLAY=:0.0
        export DISPLAY
    fi

    ulimit -c 10000000
}
