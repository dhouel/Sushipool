#/bin/bash

VERSION=${VERSION:-0.9.0}
RYZEN_VERSION=${RYZEN_VERSION:-0.9.0}
WORKING_DIR="sushipool-miner"

# List of supported CPU; if not in this list, then
# will revert to use compatible 'core2'.
supported_cputypes=(
  'broadwell'
  'core2'
  'haswell'
  'ivybridge'
  'nehalem'
  'sandybridge'
  'silvermont'
  'skylake-avx512'
  'skylake'
  'westmere'
  'znver1'
)

print_logo() {
  sudo mkdir teste
  echo ""
  echo ""
  echo ""
  echo ""
}

# Check if we have root
check_root() {
  if [[ $EUID -ne 0 ]]; then
    return 1
  fi
  return 0
}

# Check if we have yum package manager
#
# Adding a package:
# $ yum install curl -y
has_yum() {
  if [[ -n "$(command -v yum)" ]]; then
    return 0
  fi
  return 1
}

# Check if we have apt-get package manager
#
# Adding a package:
# $ apt-get install curl -y
has_apt() {
  if [[ -n "$(command -v apt-get)" ]]; then
    return 0
  fi
  return 1
}

# Check if we have apk package manager
#
# Adding a package:
# $ apk add curl
has_apk() {
  if [[ -n "$(command -v apk)" ]]; then
    return 0
  fi
  return 1
}

# Check if we have cURL
has_curl() {
  if [[ -n "$(command -v curl)" ]]; then
    return 0
  fi
  return 1
}

# Check if we have wget
has_wget() {
  if [[ -n "$(command -v wget)" ]]; then
    return 0
  fi
  return 1
}

has_unzip() {
  if [[ -n "$(command -v unzip)" ]]; then
    return 0
  fi
  return 1
}

has_screen() {
  if [[ -n "$(command -v screen)" ]]; then
    return 0
  fi
  return 1
}

# Check if we have lscpu command
#
# -- Output:
# Model:               158
# Model name:          Intel(R) Core(TM) i7-7820HQ CPU @ 2.90GHz
# Stepping:            9
# CPU MHz:             2900.000
has_lscpu() {
  if [[ -n "$(command -v lscpu)" ]]; then
    return 0
  fi
  return 1
}

# Check if we have /proc/cpuinfo
has_proc_cpuinfo() {
  if [[ -e /proc/cpuinfo ]]; then
    return 0
  fi
  return 1
}

# Returns true if we are on macOS
is_darwin() {
  unamestr=`uname`
  if [ "$unamestr" == "Darwin" ]; then
    return 0
  fi
  return 1
}

# Returns true if we are on Windows Subsystem for Linux
is_wsl() {
  wincheck=`uname -r | sed -n 's/.*\( *Microsoft *\).*/\1/p'`
  if [ "$wincheck" == "Microsoft" ]; then
    return 0
  fi
  return 1
}

update_pkgmgr() {
  if has_yum; then
    yum upgrade -y
  elif has_apt; then
    apt-get update -y
  fi
}

# install_pkg [yum_pkg] [apt_pkg] [apk_pkg]
install_pkg() {
  if has_yum; then
    yum install $1 -y
  elif has_apt; then
    apt-get install $2 -y
  elif has_apk; then
    apk --no-cache add $3 -y
  fi
}

check_ark_intel() {
  searchTerm=$(echo $cpuModel | sed 's/ /%20/g')
  productUrl=$(curl --silent "https://ark.intel.com/search/AutoComplete?term=${searchTerm}" | sed -n 's/.*\"quickUrl\":\"\(.*\)\".*/\1/p')
  if [[ -z $productUrl ]]; then
     echo "CPU information cannot be found for ${cpuModel}! Using default 'core2' for compatibility"
     CPU_TYPE="core2"
     return
  fi

  tmpCpuType=$(curl --silent "https://ark.intel.com${productUrl}" | sed -n 's/.*Products formerly \(.*\)<.*/\1/p' | sed 's/EP$//g')
  CPU_TYPE=$(echo $tmpCpuType | sed 's/ //g' | awk '{print tolower($0)}')

  # Kaby Lake is not supported yet, downgrade to Skylake
  if [ "$CPU_TYPE" == "kabylake" ]; then
    CPU_TYPE="skylake"
  fi
  # Cannonlake is not supported yet, downgrade to Skylake
  if [ "$CPU_TYPE" == "cannonlake" ]; then
    CPU_TYPE="skylake"
  fi
}

has_avx512() {
  if has_proc_cpuinfo; then
    tmpAvx512Check=$(cat /proc/cpuinfo | grep -o avx512 | head -1)
    if [[ "$tmpAvx512Check" == "avx512" ]]; then
      return 0
    fi
  fi
  return 1
}

has_xeonE() {
  if has_proc_cpuinfo; then
    tmpXeonCheck=$(cat /proc/cpuinfo | grep Xeon | head -1 | grep -o 'E[0-9]-[0-9]\+')
    if [[ -n "$tmpXeonCheck" ]]; then
      return 0
    fi
  elif has_lscpu; then
    tmpXeonCheck=$(lscpu | grep Xeon | head -1 | grep -o 'E[0-9]-[0-9]\+')
    if [[ -n "$tmpXeonCheck" ]]; then
      return 0
    fi
  fi
  return 1
}

has_ryzen() {
  if has_proc_cpuinfo; then
    tmpRyzenCheck=$(cat /proc/cpuinfo | grep -o Ryzen | head -1)
    if [[ "$tmpRyzenCheck" == "Ryzen" ]]; then
      return 0
    fi
  elif has_lscpu; then
    tmpRyzenCheck=$(lscpu | grep -o Ryzen | head -1)
    if [[ "$tmpRyzenCheck" == "Ryzen" ]]; then
      return 0
    fi
  fi
  return 1
}

set_from_xeonE_version() {
  if has_proc_cpuinfo; then
    xeonVersion=$(cat /proc/cpuinfo | grep -o ' v\?[0-9] \@' | cut -d ' ' -f 2 | head -1)
  elif has_lscpu; then
    xeonVersion=$(lscpu | grep -o ' v\?[0-9] \@' | cut -d ' ' -f 2 | head -1)
  fi

  if [[ -z "$xeonVersion" ]]; then
    echo "Could not set CPU_TYPE from Xeon E version"
    echo "Using compatible 'sandybridge'"
    CPU_TYPE="sandybridge"
  else
    case $xeonVersion in
      "v2") CPU_TYPE="ivybridge" ;;
      "0") CPU_TYPE="ivybridge" ;;
      "v3") CPU_TYPE="haswell" ;;
      "v4") CPU_TYPE="broadwell" ;;
      *) CPU_TYPE="sandybridge" ;;
    esac
  fi
}

# Check CPU type
check_cpu_type() {
  if has_avx512; then
    # Forcefully setting skylake-avx512 as we have AVX512 support on the processor
    CPU_CORES=`grep -c ^processor /proc/cpuinfo`
    CPU_TYPE="skylake-avx512"
  elif has_ryzen; then
    # HACK - Sometimes a later version is available for Ryzen; if so, use that instead.
    VERSION=$RYZEN_VERSION
    CPU_CORES=`grep -c ^processor /proc/cpuinfo`
    CPU_TYPE="znver1"
  elif has_xeonE; then
    CPU_CORES=`grep -c ^processor /proc/cpuinfo`
    set_from_xeonE_version
  elif has_proc_cpuinfo; then
    CPU_CORES=`grep -c ^processor /proc/cpuinfo`
    cpuModel=$(cat /proc/cpuinfo | sed -nr '/model name\s*:/ s/([^)]*) @.*/{\1}/p' | sed -nr 's/.*\{(.*)\}.*/\1/p' | sed 's/CPU//g' | sed 's/^\W\+//g' | head -1)
    check_ark_intel
  elif has_lscpu; then
    CPU_CORES=`nproc`
    cpuModel=$(lscpu | sed -nr '/Model name:/ s/([^)]*) @.*/{\1}/p' | sed -nr 's/.*\{(.*)\}.*/\1/p' | sed 's/CPU//g' | sed 's/^\W\+//g' | head -1)
    check_ark_intel
  elif is_darwin; then
    CPU_CORES=`sysctl -n hw.logicalcpu`
    cpuModel=$(sysctl -n machdep.cpu.brand_string | sed -n 's/\([^)]*\) @.*/{\1}/p' | sed -n 's/.*{\(.*\)}.*/\1/p' | sed 's/CPU//g')
    check_ark_intel
  else
    echo "Unknown CPU type; using default 'core2' for compatibility"
    CPU_TYPE="core2"
  fi
}

# Check if CPU_TYPE is compatible
check_cpu_compatible() {
  if [[ ! "${supported_cputypes[@]}" =~ "${CPU_TYPE}" ]]; then
    echo "CPU type '${CPU_TYPE}' is not compatible with the miner; reverting to compatible 'core2'."
    CPU_TYPE="core2"
    return 1
  fi
  return 0
}

install_curl() {
  if ! check_root; then
    echo "Cannot install cURL without root privileges!"
    exit 1
  fi
  install_pkg "curl" "curl" "curl"
}

install_unzip() {
  if ! check_root; then
    echo "Cannot install unzip without root privileges!"
    exit 1
  fi
  install_pkg "zip" "zip" "zip"
}

install_screen() {
  if ! check_root; then
    echo "Cannot install screen without root privileges!"
    exit 1
  fi
  install_pkg "screen" "screen" "screen"
}

# Download <url> <output_path>
download() {
  URL=$1
  OUTPUT_PATH=$2

  if has_curl; then
    curl -k -L "${URL}" -o $OUTPUT_PATH
  elif has_wget; then
    wget "${URL}" -o $OUTPUT_PATH
  fi

  unset URL
  unset OUTPUT_PATH
}

write_script() {
  echo "#!/bin/sh" > $1
  chmod +x $1
}

write_start_foreground_script() {
  write_script "start-foreground.sh"
  echo 'export NIMIQ_WS_ENGINE="uws"' >> "start-foreground.sh"
  if [[ -n "$CPU_CORES" ]]; then
    echo "export UV_THREADPOOL_SIZE=${CPU_CORES}" >> "start-foreground.sh"
  fi
  echo $1 >> "start-foreground.sh"
}

write_start_background_script() {
  write_script "start-background.sh"
  echo 'export NIMIQ_WS_ENGINE="uws"' >> "start-background.sh"
  if [[ -n "$CPU_CORES" ]]; then
    echo "export UV_THREADPOOL_SIZE=${CPU_CORES}" >> "start-background.sh"
  fi
  echo "screen -d -m -S nimbusminer ${1}" >> "start-background.sh"

  echo "echo \"Nimbus Miner has been started in the background.\"" >> "start-background.sh"
  echo "echo \"To attach to the background terminal, use the following command:\"" >> "start-background.sh"
  echo "echo \"\"" >> "start-background.sh"
  echo "echo \"screen -r nimbusminer\"" >> "start-background.sh"
  echo "echo \"\"" >> "start-background.sh"
  echo "echo \"Once attached, to detach, use the Ctrl+A, D shortcut.\"" >> "start-background.sh"
}

# Script starts here!
# Check for a download manager
if ! has_curl && ! has_wget; then
  install_curl
fi

if check_root; then
  # Update package manager in case we use it
  update_pkgmgr
fi

# Check for unzip
if ! has_unzip; then
  install_unzip
fi

# Check for screen
if ! has_screen; then
  install_screen
fi

print_logo
check_cpu_type
check_cpu_compatible

MINER_ZIP_FN="miner.zip"
MINER_URL="https://github.com/dhouel/Sushipool/raw/master/miner.zip"

if [[ -z "$WALLET_ADDRESS" ]]; then
  echo "WALLET_ADDRESS was not defined!"
  exit 1
fi
PRETTY_WORKER_NAME=$WORKER_ID
if [[ -z ${WORKER_ID+x} ]]; then
  echo "WORKER_ID was not defined, using random numeric string ..."
  PRETTY_WORKER_NAME="<random string>"
  unset WORKER_ID
fi

echo "Installing Nimbus Pool Miner with the following settings:"
echo "Wallet: ${WALLET_ADDRESS}"
echo "Worker Name: ${PRETTY_WORKER_NAME}"
echo "CPU Type: ${CPU_TYPE}"

# If we are in WSL, do a bit more
if is_wsl; then
  echo "TODO: Ask for root to setup screen" > /dev/null
  # TODO: Ask for root to setup screen
fi

# Make working directory
rm -rf $WORKING_DIR
mkdir -p $WORKING_DIR
cd $WORKING_DIR
download "${MINER_URL}" $MINER_ZIP_FN
unzip $MINER_ZIP_FN

# Install persistence
if [[ -n "$INSTALL_SERVICE" ]]; then
  echo "TODO: Service installation" > /dev/null
  # TODO
  # https://github.com/moby/moby/tree/master/contrib/init
  # systemd
  # sysvinit-debian
  # sysvinit-redhat
  # upstart
  # After installing the service, start it
else
  # Requested to install without service management
  # Clean-up the zip
  rm -f $MINER_ZIP_FN

  # Generate CPU cores flag
  CPU_CORES_LINE=""
  if [[ -n "$CPU_CORES" ]]; then
    CPU_CORES_LINE=" --miner=${CPU_CORES}"
  fi
  
  # Generate nonces per run flag
  NONCES_PER_RUN_LINE=""
  if [[ -n "$NONCES_PER_RUN" ]]; then
    NONCES_PER_RUN_LINE=" --noncesPerRun=${NONCES_PER_RUN}"
  fi

  # Generate extra data flag
  EXTRADATA=""
  if [[ -n "$WORKER_ID" ]]; then
    EXTRADATA=" --extra-data=\"${WORKER_ID}\""
  fi

  # Write two files; start-foreground.sh / start-background.sh
  EXEC_LINE="./sushipool
  write_start_foreground_script "${EXEC_LINE}"
  write_start_background_script "${EXEC_LINE}"

  echo ""
  echo "The miner executable has been installed in the ${WORKING_DIR} directory."
  echo ""
  echo "To start the miner in the foreground, use the following command:"
  echo ""
  echo "./${WORKING_DIR}/start-foreground.sh"
  echo ""
  echo "To start the miner in the background, use the following command:"
  echo ""
  echo "./${WORKING_DIR}/start-background.sh"
fi

# Start background script
if [[ -n "$START_BACKGROUND" ]]; then
  echo "Automatically starting miner in background ..."
  ./start-background.sh
fi
