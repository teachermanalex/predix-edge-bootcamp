#!/bin/bash
set -e

# Check to see if we are running as root; if not exit
uid=$(id | sed 's/^uid=\([0-9][0-9]*\).*/\1/' )
if [ $uid -ne 0 ] ; then
  echo 'you must run setup script as root.  Try:'
  echo "  sudo $0"
  exit 1
fi

# Check to see if you already have docker; if yes exit
$(docker >& /dev/null )
rv=$?
if [ $rv -ne 127 ] ; then
	echo Docker is already installed!  Nothing more to set up.
	exit 0
fi

# Install Docker
yum -y install docker
groupadd docker
chown root:docker /var/run/docker.sock
usermod -aG docker `whoami`

echo Docker setup completed successfully.  However, you will need to 
echo completely log out and log back in again to finish the setup.
echo
echo Your environment may not work correctly until you log out and back in.
