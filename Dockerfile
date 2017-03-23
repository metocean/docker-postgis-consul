FROM kartoza/postgis:9.5-2.2

RUN apt-get -y update && apt-get -y install wget unzip &&\
    echo "-----------------Install Consul-----------------" &&\
    cd /tmp &&\
    mkdir /consul &&\
    wget -q https://releases.hashicorp.com/consul/0.7.0/consul_0.7.0_linux_amd64.zip &&\
    wget -q https://releases.hashicorp.com/consul/0.7.0/consul_0.7.0_web_ui.zip &&\
    unzip consul_0.7.0_linux_amd64.zip &&\
    unzip -d dist consul_0.7.0_web_ui.zip &&\
    mv consul /usr/bin &&\
    mkdir -p /var/www/consul &&\
    mv dist/* /var/www/consul/ &&\
    rm -r dist consul_0.7.0_linux_amd64.zip consul_0.7.0_web_ui.zip

ADD ./entrypoint.sh /.entrypoint.sh
#ADD ./consul-service.json /consul/

ENTRYPOINT ["/.entrypoint.sh"]
CMD /start-postgis.sh