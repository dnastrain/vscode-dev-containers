#!/bin/bash
set -e

OSURL=""
OSTAG=""

find_os_props() {
    . /etc/os-release
    case $ID in
        debian)
            case $VERSION_CODENAME in
                stretch)
                    OSTAG="1683458"
                    OSURL="debian-9-stretch-amd64"
                    ;;
                *)
                    OSTAG="1683461"
                    OSURL="debian-buster-amd64"
                    ;;
            esac
            ;;
        ubuntu)
            case $VERSION_CODENAME in
                bionic)
                    OSTAG="1683439"
                    OSURL="ubuntu-bionic-amd64"
                    ;;
                groovy)
                    OSTAG="1683454"
                    OSURL="ubuntu-groovy-amd64"
                    ;;
                *)
                    OSTAG="1683444"
                    OSURL="ubuntu-focal-amd64"
                    ;;
            esac
            ;;
        *)
            echo "Unsupported OS choice."
            exit 1
            ;;
    esac
}

TMP_DIR=$(mktemp -d -t maria-XXXXXXXXXX)
MARIADB_CONNECTOR=""

cleanup() {
    EXIT_CODE=$?
    set +e
    if [[ -n ${TMP_DIR} ]]; then
        cd /
        rm -rf ${TMP_DIR}
    fi
    exit $EXIT_CODE
}
trap cleanup EXIT

#Set up external repository and install C Connector
apt install -y libmariadb3 libmariadb-dev

#Depending on the OS, install different C++ connectors
find_os_props

if [ "$(dpkg --print-architecture)" = "arm64" ] ; then
    # Instructions are copied and modified from: https://github.com/mariadb-corporation/mariadb-connector-cpp/blob/master/BUILD.md
    # and from: https://mariadb.com/docs/clients/mariadb-connectors/connector-cpp/install/
    cd ${TMP_DIR}
    apt-get update
    apt-get install -y git cmake make gcc libssl-dev
    git clone https://github.com/MariaDB-Corporation/mariadb-connector-cpp.git
    mkdir build && cd build
    cmake ../mariadb-connector-cpp/ -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCONC_WITH_UNIT_TESTS=Off -DCMAKE_INSTALL_PREFIX=/usr/local -DWITH_SSL=OPENSSL
    cmake --build . --config RelWithDebInfo
    make install

    install -d /usr/include/mariadb/conncpp/compat

    #Header Files being copied into the necessary directories
    cp -R ../mariadb-connector-cpp/include/* /usr/include/mariadb/
    cp -R ../mariadb-connector-cpp/include/conncpp/* /usr/include/mariadb/conncpp
    cp -R ../mariadb-connector-cpp/include/conncpp/compat/* /usr/include/mariadb/conncpp/compat

    install -d /usr/lib/mariadb/plugin

    #Shared libraries copied into usr/lib
    cp ./libmariadbcpp.so /usr/lib
    cp ./libmariadb/*.so /usr/lib/mariadb/plugin
else
    # Instructions are copied and modified from: https://mariadb.com/docs/clients/mariadb-connectors/connector-cpp/install/
    MARIADB_CONNECTOR=mariadb-connector-cpp-1.0.1-$OSURL
    cd ${TMP_DIR}
    curl -Ls https://dlm.mariadb.com/$OSTAG/connectors/cpp/connector-cpp-1.0.1/${MARIADB_CONNECTOR}.tar.gz -o ${MARIADB_CONNECTOR}.tar.gz
    tar -xvzf ${MARIADB_CONNECTOR}.tar.gz && cd ${MARIADB_CONNECTOR}
    install -d /usr/include/mariadb/conncpp

    #Header Files being copied into the necessary directories
    cp -R ./include/mariadb/* /usr/include/mariadb/
    cp -R ./include/mariadb/conncpp/* /usr/include/mariadb/conncpp
    cp -R ./include/mariadb/conncpp/compat/* /usr/include/mariadb/conncpp/compat

    install -d /usr/lib/mariadb
    install -d /usr/lib/mariadb/plugin

    #Shared libraries copied into usr/lib
    cp lib/mariadb/libmariadbcpp.so /usr/lib
    cp -R lib/mariadb/plugin/* /usr/lib/mariadb/plugin
fi 


