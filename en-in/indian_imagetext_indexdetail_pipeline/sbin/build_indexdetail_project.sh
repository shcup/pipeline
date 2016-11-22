#!/bin/sh
#===============================================================================
#
# Copyright (c) 2015 Letv.com, Inc. All Rights Reserved
#
#
# File:
# pipeline/indian_imagetext_pipeline_deploy/indian_imagetext_indexdetail_pipeline/sbin/build_project.sh
# Author: Li Qiang(liqiang1@letv.com)
# Modified: Shang Huaiying(shanghuaiying@le.com)
# Date: 2015/08/22 01:21:54
#
#===============================================================================
PROJ_ROOT=$(cd $(dirname $0); echo $PWD)
PROJ_BASE=$(basename $PROJ_ROOT)
PROJ_NAME=indian_image_text

PIPELINE_HOME=$(cd $PROJ_ROOT;cd ..;echo $PWD)

SHARED_HOME=$(dirname ${PIPELINE_HOME})
SHARED_SERVING_HOME=${SHARED_HOME}/serving

SEARCH2_HOME=$(dirname ${SHARED_HOME})/search2

BLADE_ROOT=$(dirname ${SHARED_HOME})

PROFILE=release

PROJ_BLADE_PATH=$(echo $PROJ_ROOT | sed -e "s,${BLADE_ROOT},,g")
PROJ_BUILD_HOME=${BLADE_ROOT}/build64_${PROFILE}/${PROJ_BLADE_PATH}
PIPELINE_BUILD_HOME=$(dirname ${PROJ_BUILD_HOME})

VERSION=0.0.1
REVISION=`svn info | grep Revision | awk -F: '{print $2;}'| tr -d ' '`
PLATFORM=`uname -m`
CURRENT_DATE=`date +%Y%m%d`

PROJ_TEST_TARGET=${PREFIX_NAME}-test-${PROFILE}-$VERSION-r$REVISION-$PLATFORM-$CURRENT_DATE.tar.gz
PROJ_PRODUCTION_TARGET=${PREFIX_NAME}-${PROFILE}-$VERSION-r$REVISION-$PLATFORM-$CURRENT_DATE.tar.gz

ASSEMBLE_DIR=$PIPELINE_HOME/assemble

PREFIX=mr_indian_imagetext_initial_pipeline
PREFIX_NAME=$(basename ${PREFIX})
PIPELINE_ASSEMBLE_DIR=$PIPELINE_HOME/assemble/$PREFIX
PIPELINE_OUTPUT_DIR=$PIPELINE_HOME/output

COMMON_DATA_FILES="                                                                             \
        bin:${PROJ_BUILD_HOME}/mr_crawl_log_convert_main                                        \
        bin:${PIPELINE_BUILD_HOME}/adapter/crawl_document_converter_main                        \
        bin:${PIPELINE_HOME}/deploy/bin/mr_indian_imagetext_indexdetail_pipeline                            \
        lib/shell:${PIPELINE_HOME}/deploy/lib/shell/mr_imagetext_pipeline_routines.sh             \
        lib/shell:${SHARED_HOME}/common/lib/shell/fs.sh                                         \
        lib/shell:${SHARED_HOME}/common/lib/shell/hdfs.sh                                       \
        lib/shell:${SHARED_HOME}/common/lib/shell/logger.sh                                     \
        lib/java:${PIPELINE_HOME}/deploy/conf/custom_format_1_1_2.jar                           \
        conf:${PIPELINE_HOME}/deploy/conf/mr_imagetext_pipeline.conf                                \
        log:                                                                                    \
        repo:                                                                                   \
        "

COMMON_DATA_FILES="                                                                             \
        jar:../jar/*.sh                                                             \
        aggregate_doc2vec:../aggregate_doc2vec/*.sh \
        aggregate_doc2vec:../aggregate_doc2vec/*.py \
        aggregate_lda:../aggregate_lda/*.py \
        aggregate_lda:../aggregate_lda/*.sh \
        sbin:../sbin/mr_indian_imagetext_indexdetail_pipeline.sh                            \
        sbin:../sbin/build_project.sh                                             \
        sbin:../sbin/transfer_data.sh                                               \
        lib/shell:../lib/shell/mr_imagetext_pipeline_routines.sh          \
        lib/shell:../lib/shell/fs.sh                                         \
        lib/shell:../lib/shell/hdfs.sh                                       \
        lib/shell:../lib/shell/logger.sh                                     \
        data:../data/iplist
        conf:../conf/mr_imagetext_pipeline.conf                           \
        conf:../conf/index_scoring.conf  \
        log:                                                                                    \
        repo:                                                                                   \
        "





TESTING_DATA_FILES="                                                                            \
"


PROJ_DATA_FILES="$COMMON_DATA_FILES $TESTING_DATA_FILES"

function usage()
{
cat <<EOF
Usage: $0 COMMAND [OPTIONS]

    build [release|debug]         Default action
    clean
    cleanbuild [release|debug]    
EOF
}


function BuildingInit()
{
    PROJ_BUILD_HOME=${BLADE_ROOT}/build64_${PROFILE}/${PROJ_BLADE_PATH}
    PROJ_TEST_TARGET=${PREFIX_NAME}-test-${PROFILE}-$VERSION-r$REVISION-$PLATFORM-$CURRENT_DATE.tar.gz
    mkdir -p ${PIPELINE_OUTPUT_DIR}
}


function BuildingInstallDataFiles()
{
    for dirfile in $1;
    do
        _data_dir=${PIPELINE_ASSEMBLE_DIR}/$(echo $dirfile | sed -e 's/:.*$//g')
        _data=$(echo $dirfile | sed -e 's/^.*://g')
        echo "Install: $_data"

        [ -d $_data_dir ] || mkdir -p $_data_dir
        [ "X$_data" != "X" ] || continue

        if [ -f $_data ]; then
            cp $_data $_data_dir/$(basename $_data)
        elif [ -d $_data ]; then
            cd $_data; tar cfz - --exclude='*svn' --exclude='*.objs' --exclude='*.o' * | (cd $_data_dir; tar xvfz -)
        fi
    done
}

# Usage : build [PROFILE] TARGET
function BuildingRun()
{
    _profile=$1

    echo "Project Building"

    cd $PROJ_ROOT
    blade build -p $_profile ./...
    [ $? -eq 0 ] || { echo "Build failed"; return 1; }

    cd $PIPELINE_HOME/adapter
    blade build -p $_profile ./...
    [ $? -eq 0 ] || { echo "Build failed"; return 1; }

    cd $PIPELINE_HOME/util
    blade build -p $_profile ./...
    [ $? -eq 0 ] || { echo "Build failed"; return 1; }
}

function BuildingPackage()
{
    _target=$1
    _data_files="$2"
    _output_dir=$PIPELINE_OUTPUT_DIR
    _assemble_dir=$ASSEMBLE_DIR/${PREFIX}

    echo "Package Target: $_target"

    rm -rf $_assemble_dir/*
    BuildingInstallDataFiles "$_data_files"

    _selected=$(for dirfile in $_data_files; do echo $dirfile | sed -e 's/:.*$//g'; done | sort -u)

    cd $_assemble_dir
    tar cvfz $_output_dir/$_target --transform "s,^,${PREFIX}/," $_selected
}

function BuildingClean()
{
    echo "Cleaning ..."
    rm -rf ${PROJ_BUILD_HOME}

    [ -d $PIPELINE_ASSEMBLE_DIR ] || return 0
    rm -rf $PIPELINE_ASSEMBLE_DIR/*
}

function mainloop()
{
    _command=build

    if [ $# -gt 0 ]; then
        _command=$1
    fi

    case $_command in 
        build)
            if [ $# -gt 1 ]; then
                PROFILE=$2
            fi
            ;;
        cleanbuild)
            if [ $# -gt 1 ]; then
                PROFILE=$2
            fi

            BuildingClean
            ;;
        clean)
            BuildingClean
            return 0
            ;;
        *)
            echo "Unknow Command"
            return 1
    esac

    case $PROFILE in
        release|debug)
            ;;
        *)
            echo "Unknow profile $PROFILE"
            return 1
    esac

    BuildingInit

#    BuildingRun $PROFILE
#    [ $? -eq 0 ] || { return 1; }

    BuildingPackage $PROJ_TEST_TARGET "$COMMON_DATA_FILES ${TESTING_DATA_FILES}"
    [ $? -eq 0 ] || { return 1; }

    BuildingClean
    return 0
}

mainloop $*






















# vim: set expandtab ts=4 sw=4 sts=4 tw=100:
