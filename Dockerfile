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
  vim

RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl \
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

RUN curl -Lo /usr/local/bin/zedrem https://github.com/lalyos/zedrem/releases/download/latest/zedrem-linux \
  && chmod +x /usr/local/bin/zedrem 
RUN kubectl completion bash > /etc/bash_completion.d/kubectl
RUN helm completion bash > /etc/bash_completion.d/helm
ADD https://raw.githubusercontent.com/cykerway/complete-alias/master/bash_completion.sh  /etc/bash_completion.d/alias-complete
ADD motd /etc/motd
ADD https://gist.githubusercontent.com/lalyos/0d28f171b365fcea51f5345e97b43279/raw/mypropmt.sh /root/.prompt.sh
ADD bash_aliases /root/.bash_aliases