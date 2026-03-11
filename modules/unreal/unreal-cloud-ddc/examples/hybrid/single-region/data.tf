# IP check for security group configuration
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}