variable "nomad_address" {
  type = string 
}

variable "nomad_token" {
  type = string
}

locals {
  address = var.nomad_address
  token   = var.nomad_token
}

job "quicklauncher" {
  datacenters = ["dc-ucmp"]
  type = "batch"

#   vault {
#     policies = ["nomad-dev"]
#     change_mode   = "signal"
#     change_signal = "SIGUSR1"
#   }
  
  parameterized {
    payload       = "forbidden"
    meta_required = ["serviceID", "port"]
    meta_optional = ["ecrTag", "toPort", "namespace"]
  }
  meta {
    ecrTag = "nginx-sample-image"
    toPort = "80"
    namespace = "default"
  }
   
  group "run-main-job" {
    task "run-main-job" {
      driver = "raw_exec"
      
      config {
        command = "nomad"
        # arguments
        args = ["job", "run",
                       "-address", "${local.address}",
                       "-token", "${local.token}",
                       "${NOMAD_TASK_DIR}/room.job"
               ]
      }
      template {
        data = <<EOH
#####################
job "{{ env "NOMAD_META_serviceID" }}" {
  datacenters = ["dc-quicklauncher"]
  namespace = "{{ env "NOMAD_META_namespace" }}"
  group "quicklauncher" {
    count = 1
    scaling {
      min = 1
      max = 30
    }
    network {
      mode = "bridge"
      port "http" {
        static = "{{ env "NOMAD_META_port" }}"
        to = "{{ env "NOMAD_META_toPort" }}"
      }
    }
    service {
      name = replace("{{ env "NOMAD_META_serviceID" }}", "_", "-")
      port = "http"
      check {
        type     = "http"
        path     = "/"
        interval = "2s"
        timeout  = "2s"
      }
    }
    task "server" {
      driver = "docker"
      
      resources {
        cpu    = 250
        memory = 500
      }
      
      config {
        image = "868771833856.dkr.ecr.ap-northeast-2.amazonaws.com/ecr-dev-quicklauncher:{{ env "NOMAD_META_ecrTag" }}"
        ports = ["http"]
      }
    }
  }
}
EOH
    destination = "local/room.job"
      }
    }
  }
}
