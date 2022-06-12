variable "nomad_address" {
  type = string 
}

variable "nomad_token" {
  type = string 
}

job "quicklauncher" {
  datacenters = ["dc-ucmp"]
  type = "batch"

  parameterized {
    payload       = "forbidden"
    meta_required = ["serviceID", "port"]
    meta_optional = ["address", "token"]
  }
  
  meta {
    address = var.nomad_address
    token   = var.nomad_token
  }

  group "run-main-job" {

    task "run-main-job" {
      driver = "raw_exec"

      config {
        command = "nomad"
        # arguments
        args = ["job", "run", "-address={{ env "NOMAD_META_address" }}", "-token={{ env "NOMAD_META_token" }}", "${NOMAD_TASK_DIR}/room.job" ]
      }
      template {
        data = <<EOH
#####################
job "{{ env "NOMAD_META_serviceID" }}" {
  datacenters = ["dc-quicklauncher"]
  group "ql_healthcheck_sample" {
    count = 1
    network {
      mode = "bridge"
      port "http" {
        static = "{{ env "NOMAD_META_port" }}"
        to = 80
      }
    }
    service {
      name = "quicklauncer-service"
      port = "http"
      connect {
        sidecar_service {}
      }
      check {
        type     = "http"
        path     = "/"
        interval = "2s"
        timeout  = "2s"
      }
    }
    task "server" {
      driver = "docker"
      config {
        image = "nginx:latest"
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
