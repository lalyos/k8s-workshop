FROM ubuntu:18.04

RUN apt-get -qq update; apt-get install -y \
  curl \
  git \
  jq \
  bash-completion \
  dnsutils \
  net-tools \
  unzip \
  tmux \
  vim \
  gettext-base

ENV KCTL_VERSION=v1.16.15
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/${KCTL_VERSION}/bin/linux/amd64/kubectl \
   && chmod +x ./kubectl \
   && mv ./kubectl /usr/local/bin/kubectl

RUN  curl -Ls https://raw.githubusercontent.com/helm/helm/master/scripts/get | bash

RUN curl -Ls https://github.com/lalyos/gotty/releases/download/v2.0.0-alpha.4/gotty_2.0.0-alpha.4_linux_amd64.tar.gz \
  | tar -xz -C /usr/local/bin

RUN  curl -L https://github.com/zyedidia/micro/releases/download/v1.4.1/micro-1.4.1-linux64.tar.gz \
  | tar -xz -C /usr/local/bin/  --strip-components 1 micro-1.4.1/micro

RUN curl -LO https://github.com/simeji/jid/releases/download/0.7.2/jid_linux_amd64.zip \
  && unzip jid_linux_amd64.zip \
  && mv jid_linux_amd64 /usr/local/bin/jid

RUN curl -sL https://github.com/sharkdp/bat/releases/download/v0.17.1/bat-v0.17.1-x86_64-unknown-linux-gnu.tar.gz | tar -xz --strip-components=1  -C /usr/local/bin  bat-v0.17.1-x86_64-unknown-linux-gnu/bat
RUN curl -Lo /usr/local/bin/caddy  https://github.com/lalyos/caddy-v1-webdav/releases/download/v1.0.5/caddy-webdav-Linux && chmod +x /usr/local/bin/caddy

RUN cd "$(mktemp -d)" \
    && curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/krew.tar.gz" \
    && tar zxvf krew.tar.gz \
    && KREW=./krew-"$(uname | tr '[:upper:]' '[:lower:]')_$(uname -m | sed -e 's/x86_64/amd64/' -e 's/arm.*$/arm/')" \
    && "$KREW" install krew

# install neovim with node and plugins
RUN curl -sL install-node.now.sh/lts | bash -s  -- -f -V
RUN curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim.appimage \
    && chmod u+x nvim.appimage
RUN ./nvim.appimage --appimage-extract
ENV PATH=$PATH:/squashfs-root/usr/bin/
RUN curl -fLo /root/.local/share/nvim/site/autoload/plug.vim --create-dirs \
       https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
RUN mkdir -p /root/.config/nvim/
RUN echo '{"yaml.schemas":{"kubernetes":["/*.yaml","/*.yml"]}}' > /root/.config/nvim/coc-settings.json
RUN echo  "call plug#begin('~/.vim/plugged')\nPlug 'neoclide/coc.nvim', {'branch': 'release'}\ncall plug#end()" > /root/.config/nvim/init.vim
RUN nvim -E -s -u /root/.config/nvim/init.vim +PlugInstall +qall
COPY init.vim /root/.config/nvim/init.vim

RUN kubectl completion bash > /etc/bash_completion.d/kubectl
RUN helm completion bash > /etc/bash_completion.d/helm
ADD https://raw.githubusercontent.com/cykerway/complete-alias/master/complete_alias  /etc/bash_completion.d/complete_alias
ADD motd /etc/motd
ADD https://gist.githubusercontent.com/lalyos/0d28f171b365fcea51f5345e97b43279/raw/mypropmt.sh /root/.prompt.sh
ADD bash_aliases /root/.bash_aliases