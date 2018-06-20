# start with the Predix Edge base alpine image
FROM dtr.predix.io/predix-edge/alpine-amd64

# set proxies your machine requires to access the Internet - remove these if not needed
ENV http_proxy=http://proxy-src.research.ge.com:8080
ENV https_proxy=http://proxy-src.research.ge.com:8080

#install nodejs into the base image
RUN apk update && apk add nodejs

# Create app directory in the image
WORKDIR /usr/src

# copy app's source files to the image
COPY src/package*.json ./
COPY src/index.js ./

# pull all required node packages into the app
RUN npm install

# start the app
CMD [ "node", "index.js" ]
