FROM kbase/kb-sdk:latest
RUN \
    rm -rf /src                     && \
    rm /etc/apt/sources.list.d/docker.list && \
    docker --version                && \
    apt-get remove -y docker-engine && \
    apt-get update -y               && \
    sudo apt-get install -y curl apt-transport-https software-properties-common && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

RUN sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"                          && \
    apt-get update -y               && \
    apt-get install -y docker-ce    && \
    docker --version

ADD . /src

RUN \
   cd /src && \
   sed -i 's/en0/eth0/' src/java/us/kbase/common/executionengine/CallbackServer.java && \
   make && \
   /src/entrypoint prune && rm -rf /src/.git

ENV PATH=$PATH:/src/bin

ENTRYPOINT [ "/src/entrypoint" ]

CMD [ ]
