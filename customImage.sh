#!/bin/bash -e

# Add a banner 
cat >> /etc/motd << EOF
*******************************************************
**                 Hello                             **
**      Welcome to a VM that was customized with     **
**            the azure image builder                 **
*******************************************************
EOF
