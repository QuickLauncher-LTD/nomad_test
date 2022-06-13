locals {
    autoscaler_ver = "0.3.3"
}
variable "nomad_address" {
  type = string
}
variable "nomad_token" {
  type = string
}

job "autoscaler" {
  datacenters = ["dc-ucmp"]

  vault {
    policies = ["admin"]
    change_mode   = "signal"
    change_signal = "SIGUSR1"
  }

  #constraint {
  #  attribute = meta.type
  #  value     = "server"
  #}

  group "autoscaler" {
    count = 1
    scaling {
      min = 0
      max = 100
    }

    network {
      port "http" {}
    }

    task "autoscaler" {
     
      driver = "exec"
      config {
        command = "/usr/local/bin/nomad-autoscaler"
        args = [
          "agent",
          "-config",
          "$${NOMAD_TASK_DIR}/config.hcl",
          "-http-bind-address",
          "0.0.0.0",
          "-http-bind-port",
          "$${NOMAD_PORT_http}",
          "-policy-dir",
          "$${NOMAD_TASK_DIR}/policies/",
        ]
      }

      artifact {
        source      = "https://releases.hashicorp.com/nomad-autoscaler/${local.autoscaler_ver}/nomad-autoscaler_${local.autoscaler_ver}_linux_amd64.zip"
        destination = "/usr/local/bin"
      }
      template {
        data        = <<EOF
nomad {
  address = var.nomad_address  #Adding nomad server addresss
  token = var.nomad_token
}

apm "nomad-apm" {
  driver = "nomad-apm"
  config  = {
    address = "http://{{env "attr.unique.network.ip-address" }}:4646"
  }
}

log_level = "DEBUG"

target "aws-asg" {
  driver = "aws-asg"
  config = {
    aws_region = "{{ $x := env "attr.platform.aws.placement.availability-zone" }}{{ $length := len $x |subtract 1 }}{{ slice $x 0 $length}}"
  }
}

strategy "target-value" {
  driver = "target-value"
}

EOF
        destination = "$${NOMAD_TASK_DIR}/config.hcl"
      }
      template {
        data = <<EOF
scaling "cluster_policy_nomadclient" {
  enabled = true
  min     = 1
  max     = 100
  
  policy {
    cooldown            = "5m"
    evaluation_interval = "20s"

    check "mem_allocated_percentage" {
      source = "nomad-apm"
      query  = "percentage-allocated_memory"
      strategy "target-value" {
        target = 70
      }
    }
    target "aws-asg" {
      dry-run             = "false"
      aws_asg_name        = "nomad_client_autoscaler"  # aws Autoscaling 그룹의 이름과 동일
      node_class          = "quicklauncher_node" # Nomad Client에 node_class속성 추가
      node_drain_deadline = "7m"
      node_purge          = "true"
    }
  }
}

EOF
        destination = "$${NOMAD_TASK_DIR}/policies/hashistack.hcl"
      }

      resources {
        cpu    = 50
        memory = 128
      }

      service {
        name = "autoscaler"
        port = "http"

        check {
          type     = "http"
          path     = "/v1/health"
          interval = "5s"
          timeout  = "2s"
        }
      }
    }
  }
}
