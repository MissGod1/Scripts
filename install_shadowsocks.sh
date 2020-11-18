#!/bin/bash
echo "[+] Install Dependent Libraries"
yum install epel-release -y
yum install gcc gettext autoconf libtool automake make pcre-devel asciidoc xmlto c-ares-devel libev-devel libsodium-devel mbedtls-devel -y

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
echo "[+] Create /etc/shadowsocks-libev/config.json"
mkdir -p /etc/shadowsocks-libev
PORT=8080
PORT2=8081
method=aes-256-gcm
PASSWD=$(cat /proc/sys/kernel/random/uuid | base64 | cut -c 1-16)
cat > /etc/shadowsocks-libev/config.json << EOF
{
 "server":"0.0.0.0",
 "server_port":${PORT},
 "password":"${PASSWD}",
 "method":"${method}",
 "workers": 10,
 "fast-open": true,
 "timeout":60
}
EOF
cat > /etc/shadowsocks-libev/config2.json << EOF
{
 "server":"0.0.0.0",
 "server_port":${PORT2},
 "password":"${PASSWD}",
 "method":"${method}",
 "workers": 10,
 "fast-open": true,
 "timeout":60
}
EOF


echo "[+] Create /usr/lib/systemd/system/shadowsocks-libev.service"
cat > /usr/lib/systemd/system/shadowsocks-libev.service << EOF
[Unit]
Description=Shadowsocks-libev Default Server Service
Documentation=man:shadowsocks-libev(8)
After=network.target network-online.target 

[Service]
Type=simple
EnvironmentFile=/etc/sysconfig/shadowsocks-libev
User=nobody
Group=nobody
LimitNOFILE=32768
ExecStart=/usr/local/bin/ss-server -c "\$CONFFILE" \$DAEMON_ARGS
CapabilityBoundingSet=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF
cat > /usr/lib/systemd/system/shadowsocks-libev2.service << EOF
[Unit]
Description=Shadowsocks-libev Default Server Service
Documentation=man:shadowsocks-libev(8)
After=network.target network-online.target 

[Service]
Type=simple
EnvironmentFile=/etc/sysconfig/shadowsocks-libev2
User=nobody
Group=nobody
LimitNOFILE=32768
ExecStart=/usr/local/bin/ss-server -c "\$CONFFILE" \$DAEMON_ARGS
CapabilityBoundingSet=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

echo "[+] Add /etc/sysconfig/shadowsocks-libev"
cat > /etc/sysconfig/shadowsocks-libev << EOF
# Defaults for shadowsocks initscript
# sourced by /etc/init.d/shadowsocks-libev
# installed at /etc/sysconfig/shadowsocks-libev by the maintainer scripts

# Enable during startup?
START=yes

# Configuration file
CONFFILE="/etc/shadowsocks-libev/config.json"

# Extra command line arguments
#DAEMON_ARGS="-u"
DAEMON_ARGS="-u --plugin \"/etc/shadowsocks-libev/v2ray-plugin\" --plugin-opts \"server\""

# User and group to run the server as
USER=nobody
GROUP=nobody

# Number of maximum file descriptors
MAXFD=32768
EOF

cat > /etc/sysconfig/shadowsocks-libev2 << EOF
# Defaults for shadowsocks initscript
# sourced by /etc/init.d/shadowsocks-libev
# installed at /etc/sysconfig/shadowsocks-libev by the maintainer scripts

# Enable during startup?
START=yes

# Configuration file
CONFFILE="/etc/shadowsocks-libev/config2.json"

# Extra command line arguments
DAEMON_ARGS="-u"
#DAEMON_ARGS="-u --plugin \"/etc/shadowsocks-libev/v2ray-plugin\" --plugin-opts \"server\""

# User and group to run the server as
USER=nobody
GROUP=nobody

# Number of maximum file descriptors
MAXFD=32768
EOF
cd ..

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

