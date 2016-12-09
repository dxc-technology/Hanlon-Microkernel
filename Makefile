TAG?=test
IMAGENAME?=jtilander/hanlon-microkernel

image:
	docker build -t $(IMAGENAME):$(TAG) .

push: image
	docker push $(IMAGENAME):$(TAG)

save:
	docker save $(IMAGENAME):$(TAG) > cscdock-mk-image.tar
	bzip2 -c cscdock-mk-image.tar > /tmp/cscdock-mk-image.tar.bz2
	rm cscdock-mk-image.tar
