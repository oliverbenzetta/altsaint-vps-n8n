# Container Name: N8N
# File Name: Dockerfile
# Description: Dockerfile for building the custom N8N image.
# Docker Internal Network: altsaint-net
# Version: 1.0.0
# Author: Alt Saint Group LTD

FROM n8nio/n8n:latest

# Extend the official n8n image if needed. For example, you can copy
# additional custom nodes or install dependencies here. The base image
# already contains all required n8n binaries.

# COPY ./custom-nodes /data/custom
# RUN npm install --prefix /data/custom && npm run build --prefix /data/custom
