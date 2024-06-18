resource "terraform_data" "manifest" {
  input = {
    users = local.users
    files = local.configs
    install = {
      packages = [
        "postgresql",
        "pgbackrest"
      ]
      repositories  = []
      systemd_units = []
    }
  }
}