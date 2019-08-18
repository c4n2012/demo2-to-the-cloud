#!/bin/bash
terraform output master_cluster_ca_certificate > ~/.kube/master_cluster_ca_certificate.pem
terraform output master_client_certificate > ~/.kube/client_certificate.pem
terraform output master_client_key > ~/.kube/client_key.pem
