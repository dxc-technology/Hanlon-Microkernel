FROM gliderlabs/alpine

ENV FACTER_VERSION 2.4.6

# Install any dependencies needed
ADD ipmitool-*.apk /tmp
RUN apk update && \
    apk add bash sed dmidecode ruby ruby-irb open-lldp util-linux open-vm-tools sudo && \
    apk add lshw --update-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/community/ --allow-untrusted && \
    apk add --allow-untrusted /tmp/ipmitool-*.apk && \
    echo "install: --no-rdoc --no-ri" > /etc/gemrc && \
    curl -o $(dirname $(gem which rubygems))/rubygems/ssl_certs/AddTrustExternalCARoot-2048.pem https://curl.haxx.se/ca/cacert.pem && \
    gem install json_pure daemons && \
    gem install facter -v ${FACTER_VERSION} && \
    find /usr/lib/ruby/gems/2.2.0/gems/facter-${FACTER_VERSION} -type f -exec sed -i 's:/proc/:/host-proc/:g' {} + && \
    find /usr/lib/ruby/gems/2.2.0/gems/facter-${FACTER_VERSION} -type f -exec sed -i 's:/dev/:/host-dev/:g' {} + && \
    find /usr/lib/ruby/gems/2.2.0/gems/facter-${FACTER_VERSION} -type f -exec sed -i 's:/host-dev/null:/dev/null:g' {} + && \
    find /usr/lib/ruby/gems/2.2.0/gems/facter-${FACTER_VERSION} -type f -exec sed -i 's:/sys/:/host-sys/:g' {} +
ADD hnl_mk*.rb /usr/local/bin/
ADD hanlon_microkernel/*.rb /usr/local/lib/ruby/hanlon_microkernel/
ADD hanlon_microkernel/facter/ /usr/local/lib/site_ruby/facter/
ADD entrypoint.sh /
ADD README.md /

ENTRYPOINT ["/entrypoint.sh"]
