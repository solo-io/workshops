#!/bin/bash

# install node
wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash -
. "/root/.nvm/nvm.sh"
nvm install node
npm install mocha -g
ln -s /root/.nvm/versions/node/*/bin/node -t /usr/local/sbin
ln -s /root/.nvm/versions/node/*/bin/mocha -t /usr/local/sbin

# Enable helper for all shells (interactive or not)
echo "source /root/.nvm/nvm.sh" >> /root/.env

# Enable bash completion for interactive shell
echo "source /root/.nvm/bash_completion" >> /etc/bash.bashrc

# Install dependencies in /root
pushd /root
npm install
popd