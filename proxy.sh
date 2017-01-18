#! /bin/bash

assignProxy() {
  PROXY_ENV="http_proxy https_proxy ftp_proxy all_proxy HTTP_PROXY HTTPS_PROXY FTP_PROXY ALL_PROXY"
  NO_PROXY_ENV="no_proxy NO_PROXY"

  for envar in $PROXY_ENV
  do
    export $envar=$1
  done
  for envar in $NO_PROXY_ENV
  do
    export $envar=$2
  done
}

git() {
  echo "Configuring git..."

  if [[ ${1} ]]; then
    /usr/bin/git config --global http.proxy $1
  else
    /usr/bin/git config --global --unset http.proxy
  fi
}

docker() {
  echo "Configuring docker..."
  proxyconf="/etc/systemd/system/docker.service.d/proxy.conf"
  hasproxy="$(sed -n "/HTTP_PROXY/p" $proxyconf)"

  if [[ ${1} ]] && [[ ! ${hasproxy} ]]; then
    sed -i "s|\(Environment=\).*\$|\1\"HTTP_PROXY=$1\" \"NO_PROXY=$2\"|" $proxyconf
    systemctl daemon-reload
    systemctl restart docker
  elif [[ ! ${1} ]] && [[ ${hasproxy} ]]; then
    sed -i "s/\(Environment=\).*\$/\1/" $proxyconf
    systemctl daemon-reload
    systemctl restart docker
  fi
}

clrProxy() {
  assignProxy "" # this is what unset does
}

# check the headers to see if http status is ok
# output the /dev/null to check exit code ($?)
# forbidden
# curl -s --head $proxy_value --connect-timeout 5 | head -n 1 | grep "HTTP/1.[01] [23].." > /dev/null

echo "looking for proxy $PROXY_WORK at port ${PROXY_PORT_WORK}..."
proxy_addr=

ping -q -c 1 -W 4 $PROXY_WORK > /dev/null

# on success export variables
if [ "$?" = "0" ]; then
  echo "proxy found setting environment..."
  proxy_addr="http://$PROXY_WORK:$PROXY_PORT_WORK"
  assignProxy $proxy_addr $NO_PROXY_WORK
else
  echo "proxy not found unsetting environment"
  clrProxy
fi

docker $proxy_addr $NO_PROXY_WORK
git $proxy_addr

echo "done"
