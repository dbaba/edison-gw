#!/usr/bin/env bash

SERVICE_NAME="candy-red"

function err {
  echo -e "\033[91m[ERROR] $1\033[0m"
}

function info {
  echo -e "\033[92m[INFO] $1\033[0m"
}

function download_and_npm_install {
  TARBALL=${TARBALL:-https://github.com/dbaba/archive/${VERSION}.tar.gz}
  info "Performing npm install ${TARBALL}..."
  npm install -g --unsafe-perm ${TARBALL}
}

function setup {
  assert_root
  assert_node_npm
  if [ "${CP_DESTS}" != "" ]; then
    rm -f "${CP_DESTS}"
    touch "${CP_DESTS}"
  fi
}

function cpf {
  cp -f $1 $2
  if [ "$?" == "0" ] && [ -f "${CP_DESTS}" ]; then
    if [ -f "$2" ]; then
      echo "$2" >> "${CP_DESTS}"
    else
      case "$2" in
        */)
        DEST="$2"
        ;;
        *)
        DEST="$2/"
        ;;
      esac
      echo "${DEST}$(basename $1)" >> "${CP_DESTS}"
    fi
  fi
}

function assert_root {
  if [[ $EUID -ne 0 ]]; then
     err "This script must be run as root"
     exit 1
  fi
}

function assert_node_npm {
  if [ `which node>/dev/null && which npm>/dev/null;echo $?` != "0" ]; then
     err "Please install Node.js and npm"
     exit 1
  fi
}

function test_system_service_arg {
  if [ "$1" == "" ]; then
    _try_systemd
  else
    SYSTEM_SERVICE_TYPE="$1"
  fi

  if [ "${SYSTEM_SERVICE_TYPE}" == "" ]; then
    err "Please provide the type of working system service. Either systemd or sysvinit is available"
    exit 1
  fi

  _test_system_service_type
}

function _try_systemd {
  if [ "${SYSTEM_SERVICE_TYPE}" != "" ]; then
    return
  fi
  RET=`which systemctl`
  if [ "$?" != 0 ]; then
    return
  fi
  SYSTEM_SERVICE_TYPE="systemd"
}

function _test_system_service_type {
  case "${SYSTEM_SERVICE_TYPE}" in
    systemd)
      ;;
    *)
    err "${SYSTEM_SERVICE_TYPE} is unsupported. Either systemd or sysvinit is available"
    exit 1
  esac
}

function cd_module_root {
  RET=`which realpath`
  RET=$?
  if [ "${RET}" == "0" ]; then
    REALPATH=`realpath "$0"`
  else
    REALPATH=`readlink -f -- "$0"`
  fi
  ROOT=`dirname ${REALPATH}`
  cd ${ROOT}
}

function resolve_version {
  if [ -f "${ROOT}/package.json" ]; then
    # https://gist.github.com/DarrenN/8c6a5b969481725a4413
    VERSION=$(cat ${ROOT}/package.json \
      | grep version \
      | head -1 \
      | awk -F: '{ print $2 }' \
      | sed 's/[",]//g' \
      | tr -d '[[:space:]]')
    LATEST=$(curl -L https://github.com/dbaba/candy-red/raw/master/package.json \
      | grep version \
      | head -1 \
      | awk -F: '{ print $2 }' \
      | sed 's/[",]//g' \
      | tr -d '[[:space:]]')
    if [ -z "${VERSION}" ]; then
      if [ -z "${LATEST}" ]; then
        err "Failed to resolve the latest version"
        exit 4
      fi
      info "Installing the latest version of CANDY RED..."
    elif [ -z "${LATEST}" ]; then
      info "Re-installing CANDY RED..."
    elif [ "${VERSION}" != "${LATEST}" ]; then
      info "Upgrading CANDY RED: ${VERSION} => ${LATEST}..."
      unset VERSION
    fi
  fi
  if [ -z "${VERSION}" ]; then
    VERSION="master"
    download_and_npm_install
    $(npm root -g)/candy-red/install.sh
    exit $?
  fi
}

function npm_install {
  RET=`npm ls | grep candy-red`
  RET=$?
  if [ "${RET}" != "0" ]; then
    info "Installing ${SERVICE_NAME}..."
    install=`npm install .`
    RET=$?
    if [ ${RET} != 0 ]; then
      err "npm install failed: code [${RET}]"
      exit ${RET}
    fi
  fi
}

function system_service_install {
  SERVICES="${ROOT}/services"
  START_SH="${SERVICES}/start_${SYSTEM_SERVICE_TYPE}.sh"

  rm -f ${SERVICES}/start_*
  cpf ${SERVICES}/_start.sh ${START_SH}
  sed -i -e "s/%SERVICE_NAME%/${SERVICE_NAME//\//\\/}/g" ${START_SH}
  sed -i -e "s/%SERVICE_HOME%/${ROOT//\//\\/}/g" ${START_SH}

  cp -f ${SERVICES}/base_environment.txt ${SERVICES}/environment
  sed -i -e "s/%HCIDEVICE%/${HCIDEVICE//\//\\/}/g" ${SERVICES}/environment
  sed -i -e "s/%NODE_OPTS%/${NODE_OPTS//\//\\/}/g" ${SERVICES}/environment

  _install_${SYSTEM_SERVICE_TYPE}
}

function _install_systemd {
  LOCAL_SYSTEMD="${SERVICES}/systemd"
  LIB_SYSTEMD="$(dirname $(dirname $(which systemctl)))"
  if [ "${LIB_SYSTEMD}" == "/" ]; then
    LIB_SYSTEMD=""
  fi
  LIB_SYSTEMD="${LIB_SYSTEMD}/lib/systemd"

  cpf ${LOCAL_SYSTEMD}/${SERVICE_NAME}.service.txt ${LOCAL_SYSTEMD}/${SERVICE_NAME}.service
  sed -i -e "s/%SERVICE_HOME%/${ROOT//\//\\/}/g" ${LOCAL_SYSTEMD}/${SERVICE_NAME}.service
  sed -i -e "s/%VERSION%/${VERSION//\//\\/}/g" ${LOCAL_SYSTEMD}/${SERVICE_NAME}.service

  cpf ${SERVICES}/environment ${LOCAL_SYSTEMD}/environment

  set -e
  cpf ${LOCAL_SYSTEMD}/${SERVICE_NAME}.service "${LIB_SYSTEMD}/system/"
  systemctl enable ${SERVICE_NAME}
  systemctl start ${SERVICE_NAME}
  info "${SERVICE_NAME} service has been installed."
}

setup
test_system_service_arg
cd_module_root
resolve_version
${ROOT}/uninstall.sh system_service
npm_install
system_service_install
