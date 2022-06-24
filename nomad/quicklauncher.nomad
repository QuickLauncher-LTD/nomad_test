variable "nomad_address" {
  type = string 
}

variable "nomad_token" {
  type = string
}

locals {
  address = var.nomad_address
  token  = var.nomad_token
}

job "quicklauncher" {
  datacenters = ["dc-ucmp"]
  type = "batch"

  vault {
    policies = ["nomad-dev"]
    change_mode   = "signal"
    change_signal = "SIGUSR1"
  }
  
  parameterized {
    payload       = "forbidden"
    meta_required = ["serviceID", "port"]
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
        to = 80
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
      
      template {
        data = <<EOF
      {{ with secret "ucmp-kv2/data/prod/ucmp_env" }}
DB_USER={{ .Data.data.rds_username }}
DB_PASS={{ .Data.data.rds_password }}
DB_URL={{ .Data.data.rds_url }}
      {{ end }}
      EOF
        destination   = "${NOMAD_SECRETS_DIR}/dbinfo.env"
        env           = true   #cloud not resolve placeholder issue  ${DB_USER}
        change_mode   = "restart"
      }
    
      config {
        image = "868771833856.dkr.ecr.ap-northeast-2.amazonaws.com/ecr-dev-quicklauncher:nginx-sample-image"
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
