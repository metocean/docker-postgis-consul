FROM kartoza/postgis:9.5-2.2

RUN apt-get -y update && apt-get -y install wget unzip &&\
    echo "-----------------Install Consul-----------------" &&\
    cd /tmp &&\
    mkdir /consul &&\
    wget -q https://releases.hashicorp.com/consul/1.0.6/consul_1.0.6_linux_amd64.zip &&\
    unzip consul_1.0.6_linux_amd64.zip &&\
    mv consul /usr/bin &&\
    rm -r consul_1.0.6_linux_amd64.zip

ADD ./entrypoint.sh /.entrypoint.sh
ADD start-postgis.sh /start-postgis.sh
RUN chmod 0755 /start-postgis.sh
#ADD ./consul-service.json /consul/

ENTRYPOINT ["/.entrypoint.sh"]
CMD /start-postgis.sh