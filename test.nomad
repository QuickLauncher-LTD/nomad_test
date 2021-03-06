job "testjob2" {
  datacenters = ["dc-quicklauncher"]
  group "test" {
    count = 1
    
    scaling {
      min = 1
      max = 29
    }
    
    network {
      mode = "bridge"
      port "http" {
        to = 5000
      }
    }
    
    vault {
      policies = ["nomad-dev"]
      change_mode   = "signal"
      change_signal = "SIGUSR1"
    }
    
    service {
      name = replace("quicklauncher-975559_QL_SVC_5", "_", "-")
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
      
      template {
        data = <<EOH
      {{ with secret "quicklauncher-kv2/data/dev/database_env/test" }}
TEST={{ .Data.data.test }}
      {{ end }}
      EOH
        destination   = "${NOMAD_SECRETS_DIR}/quicktest.env"
        env           = true   #cloud not resolve placeholder issue  ${DB_USER}
        change_mode   = "restart"
      }
    
      template {
        data = <<EOH
      {{ with secret "ucmp-kv2/data/prod/ucmp_env" }}
TESTPW={{ .Data.data.rds_password }}
      {{ end }}
      EOH
        destination   = "${NOMAD_SECRETS_DIR}/ucmptest.env"
        env           = true   #cloud not resolve placeholder issue  ${DB_USER}
        change_mode   = "restart"
      }
    
    
      config {
        image = "868771833856.dkr.ecr.ap-northeast-2.amazonaws.com/ecr-dev-quicklauncher:dev-evaltest2_853ioau5-79b2ea7f"
        ports = ["http"]
      }
    }
  }
}
