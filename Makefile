# This is a root level Makefile that is primarily used by the CI system to
# trigger builds using Docker images (for anything involving non-standard
# tools like OpenModelica).  The goal is that anybody should be able to use
# this Makefile to build the book on any machine that has Docker installed
# on it.
#
# N.B. - Any requires credentials are assumed to be provided by environment
# variables and should *not* be provided here.

BUILDER_IMAGE = mtiller/book-builder
S3BUCKET = beta.book.xogeny.com
RUN = docker run -v `pwd`:/opt/MBE/ModelicaBook -i -t $(BUILDER_IMAGE)
APPS_RUN = docker run -v `pwd`:/opt/MBE/ModelicaBook -w /opt/MBE/ModelicaBook/apps -i -t $(BUILDER_IMAGE)

.PHONY: all deploy specs results dirhtml apps api publish_server publish_web serve

all: specs results dirhtml apps

deploy: api publish_server publish_web

deps:
	#docker pull $(BUILDER_IMAGE)

specs: deps
	$(RUN) make specs

results: deps
	$(RUN) make results

dirhtml: deps
	$(RUN) make dirhtml
	$(RUN) ./find-math.sh build/dirhtml

json: deps
	$(RUN) make json

epub: deps
	$(RUN) make epub
	$(RUN) ./find-math.sh build/epub
	# find text/build/epub -name '*.html' -exec ./inline-math.sh {} \;
	# TODO: Repackage .epub file with inlined versions...

apps: deps
	$(APPS_RUN) yarn install
	$(APPS_RUN) yarn build
	$(APPS_RUN) yarn run deploy ../text/build/dirhtml/_static/interact-bundle.js

serve:
	(cd text/build/dirhtml; serve -p 5001)

# N.B. - This step can only be run by somebody who has access to the Xogeny private packages required to build the 
# API.
api:
	- rm -rf api/models
	- mkdir api/models
	tar zxf text/results/exes.tar.gz --directory api/models
	(cd api; npm install -g dockergen && npm run image)

# This target requires the DOCKER_* environment variables to be set
publish_server:
	docker login -e $(DOCKER_EMAIL) -u $(DOCKER_USER) -p $(DOCKER_PASS)
	docker push $(BUILDER_IMAGE)

# This target requires the AWS_*_KEY environment variables to be set
publish_web:
	docker run -v `pwd`:/opt/MBE/ModelicaBook -e "AWS_ACCESS_KEY_ID=$(AWS_ACCESS_KEY)" -e "AWS_SECRET_KEY=$(AWS_SECRET_KEY)" -e "S3BUCKET=$(S3BUCKET)" -i -t $(BUILDER_IMAGE) make web