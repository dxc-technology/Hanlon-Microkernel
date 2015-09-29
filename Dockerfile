FROM gliderlabs/alpine

# Install any dependencies needed
RUN apk update && \
    apk add bash sed dmidecode ruby ruby-irb open-lldp util-linux open-vm-tools sudo && \
    apk add lshw ipmitool --update-cache --repository http://dl-3.alpinelinux.org/alpine/edge/testing/ --allow-untrusted && \
    echo "install: --no-rdoc --no-ri" > /etc/gemrc && \
    gem install facter json_pure daemons && \
    find /usr/lib/ruby/gems/2.2.0/gems/facter-2.4.4 -type f -exec sed -i 's:/proc/:/host-proc/:g' {} + && \
    find /usr/lib/ruby/gems/2.2.0/gems/facter-2.4.4 -type f -exec sed -i 's:/dev/:/host-dev/:g' {} + && \
    find /usr/lib/ruby/gems/2.2.0/gems/facter-2.4.4 -type f -exec sed -i 's:/host-dev/null:/dev/null:g' {} + && \
    find /usr/lib/ruby/gems/2.2.0/gems/facter-2.4.4 -type f -exec sed -i 's:/sys/:/host-sys/:g' {} +
ADD hnl_mk*.rb /usr/local/bin/
ADD hanlon_microkernel/*.rb /usr/local/lib/ruby/hanlon_microkernel/
