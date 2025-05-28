
variable "configmap_metadata" {
  type = list(object({
    name      = string
    namespace = string
  }))
  default = [
    {
      name      = "wl-ds-global-functions"
      namespace = "ingress-nginx"
    },
    {
      name      = "wl-ds-server-logic-conf"
      namespace = "ingress-nginx"
    },
    {
      name      = "wl-ds-global-maps-conf"
      namespace = "ingress-nginx"
    },
    {
      name      = "wl-ds-rewrite-dispatcher"
      namespace = "ingress-nginx"
    },
    {
      name      = "wl-ds-server-vars-conf"
      namespace = "ingress-nginx"
    }
  ]
}

locals {
  config_files   = ["global-functions.lua", "server_logic.conf", "global_maps.conf", "rewrite_dispatcher.lua", "server_vars.conf"]
  config_content = [for filename in local.config_files : file("../configs/${filename}")]

  configmaps = [
    for idx, metadata in var.configmap_metadata : {
      apiVersion = "v1"
      kind       = "ConfigMap"
      metadata   = metadata
      data = {
        local.config_files[idx] = local.config_content[idx]
      }
    }
  ]
}

resource "kubectl_manifest" "global_function" {
  for_each          = { for configmap in local.configmaps : configmap.metadata.name => configmap }
  yaml_body         = yamlencode(each.value)
  depends_on        = [local.configmaps]
  server_side_apply = true
  #force_new = true
}

