Manually create manage account for rpoject in GCP IAM
Download json authorization key to ~/.kube/<project_name.json>
Change variable "gloud_creds_file" in file variables.tf to your authorization json file from the previous step
install terraform v 12.4, helm-v2.14.3, kubectl 
clone this repo git 
cd to demo2-to-the-cloud
run "terraform init"
run "terraform plan"
run "terraform apply"
Connect to GKE web console and view your internet address for Jenkins
  or run "get service --namespace jenkins --kubeconfig=kubeconfig" 
