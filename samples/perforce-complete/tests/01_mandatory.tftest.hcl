run "unit_test" {
  command = plan
  module {
    source = "./"
  }
}

# run "e2e_test" {
#   command = apply
#   module {
#     source = "./"
#   }
# }
