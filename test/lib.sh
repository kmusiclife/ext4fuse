function e4test_init {
    echo -n `basename $0`
    TIMING_SLEEP=0
}

function e4test_declare_slow {
    if [ -n "$SKIP_SLOW_TESTS" ] ; then
        echo ": SKIPPED"
        exit 0
    fi
}

function e4test_sleep {
    sleep $1
    if [ -n "$TIMING_START" -a -z "$TIMING_END" ] ; then
        TIMING_SLEEP=$(($TIMING_SLEEP + $1 * 1000000000))
    fi
}

function e4test_make_LOGFILE {
    export LOGFILE="test/logs/`basename $0 | cut -d\- -f1`-`date +%y%m%d-%H:%M.%S`"
    mkdir -p `dirname $LOGFILE`
}

function e4test_make_MOUNTPOINT {
    [ ! -f "$FS" ] && echo "No FS"
    export MOUNTPOINT="$FS-mount"
}

function e4test_make_FS {
    export FS=`mktemp /tmp/ext4fuse-test.XXXXXXXX`
    dd if=/dev/zero of=$FS bs=$((1024 * 1024)) count=$1 &> /dev/null
    mke2fs -F -t ext4 $FS &> /dev/null
}

function e4test_mount {
    mkdir $MOUNTPOINT
    sudo mount -o loop -t ext4 $FS $MOUNTPOINT
}

function e4test_fuse_mount {
    mkdir $MOUNTPOINT
    if [ -z "$LOGFILE" ]
    then
        ./ext4fuse $FS $MOUNTPOINT
    else
        ./ext4fuse $FS $MOUNTPOINT $LOGFILE
    fi
}

function e4test_fuse_mount_callgrind {
    mkdir $MOUNTPOINT
    if [ -z "$LOGFILE" ]
    then
        valgrind --tool=callgrind ./ext4fuse $FS $MOUNTPOINT
    else
        valgrind --tool=callgrind ./ext4fuse $FS $MOUNTPOINT $LOGFILE
    fi
}

function e4test_umount {
    sudo umount $MOUNTPOINT
    rmdir $MOUNTPOINT
}

function e4test_fuse_umount {
    fusermount -u $MOUNTPOINT
    sleep 0.2           # Dirty hack: sometimes rmdir comes to fast...
    rmdir $MOUNTPOINT
}

function e4test_mountpoint_struct_md5 {
    # Here we skip lost+found since user doesn't normally have permission to
    # read it.  find(1) sure has a trippy syntax...
    find $MOUNTPOINT -name lost+found -prune -o -name \* | sort | md5sum | cut -d\  -f1
}

function e4test_run {
    echo -n ': '
    TEST_TIMES=10
    TIMING_START=`date +%s%N`
    for i in `seq 1 $TEST_TIMES`
    do
        $1
    done
    TIMING_END=`date +%s%N`
    TIMING_DIFF=$(($TIMING_END - $TIMING_START))
    TIMING_DIFF=$(($TIMING_DIFF - $TIMING_SLEEP))
    TIMING_DIFF=$(($TIMING_DIFF / $TEST_TIMES))
    TIMING_DIFF_SECS=$((TIMING_DIFF / 1000000000))
    TIMING_DIFF_NSECS=$((TIMING_DIFF % 1000000000))
    TIMING_DIFF_MSECS=$((TIMING_DIFF_NSECS / 1000000))
}

function e4test_end {
    if [ ! -z "$1" ] ; then
        if ! $1 ; then
            echo FAIL
            return 1
        fi
    fi

    if grep ASSERT $LOGFILE ; then
        echo FAIL
        return 1
    fi

    printf "PASS [%d.%03ds]\n" $TIMING_DIFF_SECS $TIMING_DIFF_MSECS
}

e4test_init
