#!/usr/bin/env bash

set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="${DIR}/../"

function wait_pod_exists() {
    LABEL=$1
    NAMESPACE=$2

    for i in {1..60}; do
        if [[ "$(kubectl get po -l ${LABEL} -n ${NAMESPACE})" != "" ]]; then
            echo "[INFO] Pod with label ${LABEL} in namespace ${NAMESPACE} exists"
            return
        else
            echo "[WARN] Pod with label ${LABEL} in namespace ${NAMESPACE} does not exist"
            sleep 5
        fi
    done
    exit 1
}

function install_tekton_kube() {
    echo "[INFO] installing tekton operator on kubernetes cluster"
    kubectl apply -f https://storage.googleapis.com/tekton-releases/operator/latest/release.yaml

    wait_pod_exists "app=tekton-operator" "tekton-operator"
    kubectl wait pod -l app=tekton-operator -n tekton-operator --for condition=ready --timeout 120s

    kubectl apply -f https://raw.githubusercontent.com/tektoncd/operator/main/config/crs/kubernetes/config/all/operator_v1alpha1_config_cr.yaml

    wait_pod_exists "app=tekton-pipelines-controller" "tekton-pipelines"
    kubectl wait pod -l app=tekton-pipelines-controller -n tekton-pipelines --for condition=ready --timeout 120s

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

    wait_pod_exists "name=openshift-pipelines-operator" "openshift-operators"
    kubectl wait pod -l name=openshift-pipelines-operator -n openshift-operators --for condition=ready --timeout 120s

    kubectl apply -f https://raw.githubusercontent.com/tektoncd/operator/main/config/crs/openshift/config/all/operator_v1alpha1_config_cr.yaml

    wait_pod_exists "app=tekton-pipelines-controller" "openshift-pipelines"
    kubectl wait pod -l app=tekton-pipelines-controller -n openshift-pipelines --for condition=ready --timeout 120s

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
echo "[INFO] waiting 120s for tekton warmup"
sleep 120
