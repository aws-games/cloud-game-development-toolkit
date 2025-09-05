# Get current IP for security groups
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}