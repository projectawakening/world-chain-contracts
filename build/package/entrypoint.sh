#!/bin/sh

case "$1" in
    "deploy-v1")
        shift
        exec ./build/package/deploy.sh "$@"
        ;;
    "deploy-v2")
        shift
        exec ./build/package/deploy-v2.sh "$@"
        ;;
    "upgrade-v1")
        shift
        exec ./build/package/upgrade.sh "$@"
        ;;
    "upgrade-v2")
        shift
        exec ./build/package/upgrade-v2.sh "$@"
        ;;
    *)
        echo "Usage: $0 {deploy-v1|deploy-v2|upgrade-v1|upgrade-v2} [options]"
        echo "  deploy-v1: Deploy a new v1 world"
        echo "  deploy-v2: Deploy a new v2 world"
        echo "  upgrade-v1: Upgrade an existing v1 world"
        echo "  upgrade-v2: Upgrade an existing v2 world"
        exit 1
        ;;
esac 
