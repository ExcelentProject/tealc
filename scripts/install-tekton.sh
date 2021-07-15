#!/usr/bin/env bash

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="${DIR}/../"

function install_tekton_kube() {
    echo "[INFO] installing tekton operator on kubernetes cluster"
    kubectl apply -f https://storage.googleapis.com/tekton-releases/operator/latest/release.yaml
    kubectl apply -f https://raw.githubusercontent.com/tektoncd/operator/main/config/crs/kubernetes/config/all/operator_v1alpha1_config_cr.yaml
    echo "[INFO] tekton is installed on kubernetes cluster"
}

function install_tekton_ocp() {
    echo "[INFO] installing tekton operator on openshift cluster using OLM"
    cat << EOF | kubectl apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
    name: openshift-pipelines-operator
    namespace: openshift-operators
spec:
    channel: stable
    name: openshift-pipelines-operator-rh
    source: redhat-operators
    sourceNamespace: openshift-marketplace
EOF
    kubectl wait pod -l name=openshift-pipelines-operator -n openshift-operators --for condition=ready
    kubectl apply -f https://raw.githubusercontent.com/tektoncd/operator/main/config/crs/openshift/config/all/operator_v1alpha1_config_cr.yaml
    echo "[INFO] tekton is installed on openshift cluster"
}

#Test requrements
TEST=$(which kubectl)
if [ $? -gt 0 ]; then
    echo "[ERROR] kubectl command not found"
    exit 1
fi

#Test if cluster is openshift or kubernetes
if [[ "$(kubectl api-versions)" == *"openshift.io"* ]]; then
    install_tekton_ocp
else
    install_tekton_kube
fi