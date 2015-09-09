FROM gliderlabs/alpine

ENV REPOSITORY_URL="https://github.com/tjmcs/Hanlon-Microkernel" \
    BRANCH="tb/support-coreos-as-mk"

# Install any dependencies needed
RUN apk update && \
    apk add bash dmidecode ruby open-lldp util-linux open-vm-tools git && \
    apk add lshw ipmitool --update-cache --repository http://dl-3.alpinelinux.org/alpine/edge/testing/ --allow-untrusted && \
    echo "install: --no-rdoc --no-ri" > /etc/gemrc && \
    gem install facter json_pure daemons && \
    find /usr/lib/ruby/gems/2.2.0/gems/facter-2.4.4 -type f -exec sed -i 's:/proc/:/host-proc/:g' {} + && \
    find /usr/lib/ruby/gems/2.2.0/gems/facter-2.4.4 -type f -exec sed -i 's:/dev/:/host-dev/:g' {} + && \
    find /usr/lib/ruby/gems/2.2.0/gems/facter-2.4.4 -type f -exec sed -i 's:/host-dev/null:/dev/null:g' {} + && \
    find /usr/lib/ruby/gems/2.2.0/gems/facter-2.4.4 -type f -exec sed -i 's:/sys/:/host-sys/:g' {} + && \
    cd /tmp && \
    git clone -b $BRANCH $REPOSITORY_URL && \
    cp Hanlon-Microkernel/hnl_mk_*.rb /usr/local/bin && chmod +x /usr/local/bin/hnl_mk_*.rb && \
    cp -r Hanlon-Microkernel/hanlon_microkernel/ /usr/lib/ruby/gems/*/gems && \
    apk del git
