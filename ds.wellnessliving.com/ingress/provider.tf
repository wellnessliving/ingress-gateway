
terraform {
  backend "s3" {
    bucket = "tf.k8s.state"
    region = "us-east-1"                                                                           # !!!!! Always stored in this region
    key    = "us-east-1/thoth-sandbox/apps/ingress-ds.wellnessliving.com/terraform.tfstate" # !!!!! Always unique key for EACH application
  }
  required_providers {
    kubectl = {
      source = "gavinbunney/kubectl"
      #version = ">= 1.7.0"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}



