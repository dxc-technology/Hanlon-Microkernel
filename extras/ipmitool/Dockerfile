FROM alpine:latest

RUN apk --no-cache add alpine-sdk coreutils \
  && adduser -G abuild -g "Alpine Package Builder" -s /bin/ash -D builder \
  && echo "builder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers 
COPY README.md /
COPY entrypoint.sh /
  
WORKDIR /home/builder/
USER builder

ENTRYPOINT ["/entrypoint.sh"]


ENV RSA_PRIVATE_KEY_NAME ssh.rsa
ENV PACKAGER_PRIVKEY /home/builder/${RSA_PRIVATE_KEY_NAME}
