provider "google" {
 credentials = "${var.gloud_creds_file}"
 project     = "${var.project_name}"
 region      = "${var.location}"
 zone        = "${var.location}-a"
 version = "~> 2.5"
}

# // Terraform plugin for creating random ids
# resource "random_id" "instance_id" {
#  byte_length = 8
# }

resource "google_container_cluster" "primary" {
  name     = "${var.cluster_name}"
  location = "${var.location}-a"
  initial_node_count = "${var.node-count}"
  min_master_version = "${var.kubernetes_ver}"
  remove_default_node_pool = true

  master_auth {
    username = "fds382lkj-2-0kkjlww"
    password = "rewqr23crwejrr01efew92"

    client_certificate_config {
      issue_client_certificate = false
    }
  }

}
  resource "google_container_node_pool" "primary" {
  name       = "${var.cluster_name}-node-pool"
  project    = "${var.project_name}"
  location   = "${var.location}-a"
  cluster    = "${google_container_cluster.primary.name}"
  node_count = "${var.node-count}"

  node_config {
    preemptible  = false
    machine_type = "${var.machine_type}"

    metadata = {
      disable-legacy-endpoints = "true"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
    
  }
}

# output "master_client_certificate" {
#   value = "${google_container_cluster.primary.master_auth.0.client_certificate}"
# }

# output "master_client_key" {
#   value = "${google_container_cluster.primary.master_auth.0.client_key}"
# }

# output "master_cluster_ca_certificate" {
#   value = "${google_container_cluster.primary.master_auth.0.cluster_ca_certificate}"
# }
output "cluster_ip" {
  value = "${google_container_cluster.primary.endpoint}"
}

provider "kubernetes" {
  host = "https://${google_container_cluster.primary.endpoint}"
  # client_certificate = "${base64decode(google_container_cluster.primary.master_auth.0.client_certificate)}"
  # client_key = "${base64decode(google_container_cluster.primary.master_auth.0.client_key)}"
  cluster_ca_certificate = "${base64decode(google_container_cluster.primary.master_auth.0.cluster_ca_certificate)}"

  username = google_container_cluster.primary.master_auth[0].username
  password = google_container_cluster.primary.master_auth[0].password
}


data "template_file" "kubeconfig" {
  template = file("kubeconfig-template.yaml")

  vars = {
    cluster_name    = google_container_cluster.primary.name
    user_name       = google_container_cluster.primary.master_auth[0].username
    user_password   = google_container_cluster.primary.master_auth[0].password
    endpoint        = google_container_cluster.primary.endpoint
    cluster_ca      = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
    client_cert     = google_container_cluster.primary.master_auth[0].client_certificate
    client_cert_key = google_container_cluster.primary.master_auth[0].client_key
  }
}
resource "local_file" "kubeconfig" {
  content  = data.template_file.kubeconfig.rendered
  filename = "kubeconfig"
}

data "template_file" "helm_values" {
  template = file("helm_values_template.yaml")
  vars = {
    PROJECT    = "${var.project_name}"
  }
}
resource "local_file" "helm_values" {
  content  = data.template_file.helm_values.rendered
  filename = "helm_values.txt"
}

resource "kubernetes_namespace" "prod" {
  metadata {
    name = "prod"
  }
  depends_on = ["google_container_node_pool.primary"]
}

resource "kubernetes_namespace" "dev" {
  metadata {
    name = "dev"
  }
  depends_on = ["google_container_node_pool.primary"]
}

resource "kubernetes_namespace" "jenkins" {
  metadata {
    name = "jenkins"
  }
  depends_on = ["google_container_node_pool.primary"]
}
resource "kubernetes_secret" "jenkins-gcr-json" {
  metadata {
    name = "jenkins-gcr-json"
    namespace = "jenkins"
  }
  data = {
    "jenkins-gcr.json" = "${file ("${var.storage_creds_file}")}"
  }
  depends_on = ["google_container_node_pool.primary","local_file.kubeconfig","kubernetes_namespace.jenkins"]
}

resource "null_resource" "configure_tiller_jenkins" {
  provisioner "local-exec" {
    command = <<LOCAL_EXEC
kubectl config use-context "tf-k8s-gcp-test" --kubeconfig=${local_file.kubeconfig.filename}
kubectl apply -f helm/create-helm-service-account.yml --kubeconfig=${local_file.kubeconfig.filename}
kubectl apply -f helm/create-jenkins-service-account.yml --kubeconfig=${local_file.kubeconfig.filename}
helm init --service-account helm --upgrade --wait --kubeconfig=${local_file.kubeconfig.filename}
helm install --name jenkins --namespace jenkins --values helm_values.txt -f helm/jenkins-chart.yaml stable/jenkins --wait --kubeconfig=${local_file.kubeconfig.filename}
# get service --namespace jenkins --kubeconfig=kubeconfig
LOCAL_EXEC
  }
  depends_on = ["google_container_node_pool.primary","local_file.kubeconfig","kubernetes_namespace.jenkins"]
}
