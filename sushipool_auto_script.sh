#/bin/bash
# Desenvolvido Por: Dhouel
# Instalador autonomo Sushipool.

sudo apt-get install -y gcc g++ make nodejs dialog screen curl git
curl -sL https://deb.nodesource.com/setup_9.x -o nodesource_setup.sh
sudo bash nodesource_setup.sh
sudo apt-get install -y nodejs

curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
sudo apt-get update && sudo apt-get install -y yarn build-essential
yarn

if grep -q Microsoft /proc/version; then
    echo 'WSL detected, applying workaround.'
    sed -i 's/dist\/lmdb.js/dist\/leveldb.js/' node_modules/@nimiq/jungle-db/package.json
fi

RED='\033[0;31m'
NC='\033[0m' # No Color
git clone https://github.com/dhouel/Sushipool/tree/master/miner
cd miner
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
CPU_CORES=$((CPU_CORES-1))
sed -i 's/"threads":/"threads":\'" $CPU_CORES/" sushipool.conf
sed -i 's/"address": /"address": \'"${WALLET_ADDRESS}/"  sushipool.conf
screen ./sushipool
