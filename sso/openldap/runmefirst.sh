#!/usr/bin/env bash
git clone git@github.com:TalkingQuickly/kubernetes-sso-guide.git
helm upgrade --install openldap kubernetes-sso-guide/charts/openldap \
       --namespace openldap-service \
       --create-namespace \
       --values values-openldap.yaml
