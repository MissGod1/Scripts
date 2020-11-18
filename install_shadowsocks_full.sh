#!/bin/bash
conf=/etc/shadowsocks-libev
function new_json_config()
{
echo "[+] Create JsonConfig $conf/$1"
cat > $conf/$1.json << EOF
{
    "server":"0.0.0.0",
    "server_port":$2,
    "password":"$3",
    "method":"$4",
    "workers": 10,
    "fast-open": true,
    "timeout":60
}
EOF
}
function new_service_config()
{
echo "[+] Create ServiceConfig $conf/$1.conf"
cat > $conf/$1.conf << EOF
# Defaults for shadowsocks initscript
# sourced by /etc/init.d/shadowsocks-libev
# installed at /etc/sysconfig/shadowsocks-libev by the maintainer scripts

# Enable during startup?
START=yes

# Configuration file
CONFFILE="$conf/$1.json"

# Extra command line arguments
DAEMON_ARGS="$2"

# User and group to run the server as
USER=nobody
GROUP=nobody

# Number of maximum file descriptors
MAXFD=32768
EOF
}
function new_service()
{
echo "[+] Create /usr/lib/systemd/system/$1.service"
cat > /usr/lib/systemd/system/$1.service << EOF
[Unit]
Description=Shadowsocks-libev Default Server Service
Documentation=man:shadowsocks-libev(8)
After=network.target network-online.target 

[Service]
Type=simple
EnvironmentFile=$conf/$1.conf
User=nobody
Group=nobody
LimitNOFILE=32768
ExecStart=/usr/local/bin/ss-server -c "\$CONFFILE" \$DAEMON_ARGS
CapabilityBoundingSet=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF
}

echo "[+] Install Dependent Libraries"
flag=0

cat /etc/centos-release 2>&1 1>&/dev/null
if [ $? -eq 0 ] && [ $flag -eq 0 ]; then
    echo 'Centos'
    yum install epel-release -y
    yum install gcc gettext autoconf libtool automake make pcre-devel asciidoc xmlto c-ares-devel libev-devel libsodium-devel mbedtls-devel wget curl -y
    flag=1
fi

lsb_release -i 2>&1 1>&/dev/null
if [ $? -eq 0 ] && [ $flag -eq 0 ]; then
    echo 'Ubuntu'
    sudo apt-get update
    sudo apt-get install gettext build-essential autoconf libtool libpcre3-dev asciidoc xmlto libev-dev libc-ares-dev automake libmbedtls-dev libsodium-dev wget curl -y
    flag=1
fi

if [ $flag -eq 0 ]; then
    echo "[-] unsupport."
    exit
fi

echo "[+] Get Shadowsocks Release"
download_url=$(curl -s "https://api.github.com/repos/shadowsocks/shadowsocks-libev/releases/latest" | awk -F'"' '/browser_download_url/{print $4}')
filename=$(echo $download_url | awk -F '/' '{print $NF}')
dirname=$(echo $filename | awk -F '.tar.gz' '{print $1}')
echo "[+] Download Shadowsocks"
wget ${download_url}
tar -zxvf ${filename}

cd ${dirname}
# Start building
sudo ./configure && sudo make && sudo make install

echo "[+] Create configure file"
mkdir -p /etc/shadowsocks-libev 2>&1 1>&/dev/null
PORT=8080
PORT2=8081
method=aes-256-gcm
PASSWD=$(cat /proc/sys/kernel/random/uuid | base64 | cut -c 1-16)

new_json_config "shadowsocks-libev" $PORT $PASSWD $method
new_json_config "shadowsocks-libev2" $PORT2 $PASSWD $method

new_service_config "shadowsocks-libev" "-u"
new_service_config "shadowsocks-libev2" "-u --plugin \"/etc/shadowsocks-libev/v2ray-plugin\" --plugin-opts \"server\""

new_service "shadowsocks-libev"
new_service "shadowsocks-libev2"

# Download V2ray_Plugin
plugin_url=$(curl -s "https://api.github.com/repos/shadowsocks/v2ray-plugin/releases/latest" | awk -F'"' '/browser_download_url.*linux-amd64/{print $4}')
wget ${plugin_url} -O v2ray-plugin.tar.gz
tar -zxvf v2ray-plugin.tar.gz
mv v2ray-plugin_linux_amd64 /etc/shadowsocks-libev/v2ray-plugin


# echo "[+] install BBR and set boot option"
# rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
# rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm
# yum --enablerepo=elrepo-kernel install kernel-ml -y
# echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
# echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
# 设置启动项
# 设置启动顺序
#egrep ^menuentry /etc/grub2.cfg | cut -f 2 -d \'
# grub2-set-default 0
# 重启
#reboot
systemctl enable shadowsocks-libev
systemctl enable shadowsocks-libev2
systemctl start shadowsocks-libev
systemctl start shadowsocks-libev2
echo "PORT: ${PORT} ${PORT2}"
echo "PASSWD: ${PASSWD}"
IP=$(curl -s ipv4bot.whatismyipaddress.com)
echo ss://$(echo ${method}:${PASSWD}@${IP}:${PORT} | base64)
echo ss://$(echo ${method}:${PASSWD}@${IP}:${PORT2} | base64)