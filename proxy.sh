#! /bin/bash

##### VARIABLES
dockerconf="/etc/systemd/system/docker.service.d/proxy.conf"
dockerhasproxy="$(sed -n "/HTTP_PROXY/p" $dockerconf)"
PROXY_ENV="http_proxy https_proxy ftp_proxy all_proxy HTTP_PROXY HTTPS_PROXY FTP_PROXY ALL_PROXY"
NO_PROXY_ENV="no_proxy NO_PROXY"
proxy_addr="http://$PROXY_WORK:$PROXY_PORT_WORK"
no_proxy_addr=$NO_PROXY_WORK
#####

assignProxy() {
  for envar in $PROXY_ENV
  do
    export $envar="$proxy_addr"
  done
  for envar in $NO_PROXY_ENV
  do
    export $envar="$no_proxy_addr"
  done
}

npm() {
  npmproxy="$(/usr/bin/npm config get proxy)"

  if [[ -z "${proxy_addr}" && "${npmproxy}" != "null" ]]; then
    echo "Removing proxy from npm..."
    /usr/bin/npm config rm proxy
    /usr/bin/npm config rm https-proxy
  elif [[ "${proxy_addr}" && "${npmproxy}" = "null" ]]; then
    echo "Adding proxy to npm..."
    /usr/bin/npm config set proxy ${proxy_addr}
    /usr/bin/npm config set https-proxy ${proxy_addr}
  fi
}

git() {
  gitproxy="$(/usr/bin/git config --global http.proxy)"

  # if the proxy exits and git has it, unset it
  if [[ -z "${proxy_addr}" && "${gitproxy}" ]]; then
    echo "Removing proxy from git..."
    /usr/bin/git config --global --unset http.proxy
  #else if there is a proxy and git does not have it set it
  elif [[ "${proxy_addr}" && -z "${gitproxy}" ]]; then
    echo "Adding proxy to git..."
    /usr/bin/git config --global http.proxy ${proxy_addr}
  fi
}

docker() {
  if [[ "${proxy_addr}" && -z "${dockerhasproxy}" ]]; then
    echo "Adding proxy to docker..."
    sed -i "s|\(Environment=\).*\$|\1\"HTTP_PROXY=$proxy_addr\" \"NO_PROXY=$no_proxy_addr\"|" $dockerconf
    systemctl daemon-reload
    systemctl restart docker
  elif [[ -z "${proxy_addr}" && "${dockerhasproxy}" ]]; then
    echo "Removing proxy from docker..."
    sed -i "s/\(Environment=\).*\$/\1/" $dockerconf
    systemctl daemon-reload
    systemctl restart docker
  fi
}

pacman() {
  pacmanconf="/etc/pacman.conf"
  xfercmds="$(sed -n "/^XferCommand/p" $pacmanconf)"

  if [[ -z "${proxy_addr}" && "${xfercmds}" ]]; then
    echo "Removing wget for pacman..."
    sed -i "s/^XferCommand/#\0/g" ${pacmanconf}
  elif [[ "${proxy_addr}" && -z "${xfercmds}" ]]; then
    echo "Using wget for pacman..."
    sed -i "s/^#\(XferCommand = \/usr\/bin\/wget\)/\1/g" ${pacmanconf}
  fi
}

# check the headers to see if http status is ok
# output the /dev/null to check exit code ($?)
# forbidden
# curl -s --head $proxy_value --connect-timeout 5 | head -n 1 | grep "HTTP/1.[01] [23].." > /dev/null

echo "looking for proxy $PROXY_WORK at port ${PROXY_PORT_WORK}..."

ping -q -c 1 -W 4 $PROXY_WORK > /dev/null

#while true; do
  #read -p "Do you want to connect to ${PROXY_WORK}:${PROXY_PORT_WORK}" yn
  #case $yn in
    #[Yy]* )
      #echo "setting environment..."
      #assignProxy $proxy_addr $no_proxy_addr
      #break;;
    #[Nn]* )
      #echo "unsetting environment"
      #proxy_addr=
      #no_proxy_addr=
      #assignProxy "" # this is what unset does
      #break;;
    #* ) echo "Please answer yes or no"
  #esac
#done

 #on success export variables
if [ "$?" = "0" ]; then
  echo "proxy found setting environment..."
  assignProxy $proxy_addr $no_proxy_addr
else
  echo "proxy not found unsetting environment"
  proxy_addr=
  no_proxy_addr=
  assignProxy "" # this is what unset does
fi

docker
git
pacman
npm

echo "done"
