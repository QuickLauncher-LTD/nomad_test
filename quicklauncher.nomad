job "testjob" {
  datacenters = ["dc-quicklauncher"]
  group "test" {
    count = 1
    network {
      mode = "bridge"
      port "http" {
        to = 80
      }
    }
    service {
      name = "test-service"
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
      {{ with secret "quicklauncher-kv2/data/dev/database_env" }}
TEST={{ .Data.data.test }}
      {{ end }}
      EOH
        destination   = "${NOMAD_SECRETS_DIR}/quicktest.env"
        env           = true   #cloud not resolve placeholder issue  ${DB_USER}
        change_mode   = "restart"
      }
    
      template {
        data = <<EOH
      {{ with secret "quicklauncher-kv2/data/prod/ucmp_env" }}
TESTPW={{ .Data.data.rds_password }}
      {{ end }}
      EOH
        destination   = "${NOMAD_SECRETS_DIR}/ucmptest.env"
        env           = true   #cloud not resolve placeholder issue  ${DB_USER}
        change_mode   = "restart"
      }
    
    
      config {
        image = "nginx:latest"
        ports = ["http"]
      }
    }
  }
}
