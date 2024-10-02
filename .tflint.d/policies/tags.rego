package tflint

import rego.v1

aws_resources := terraform.resources("*", {"tags": "map(string)"}, {"expand_mode": "none"})

# Note that incrementally defined rules can intuitively be understood as <rule-1> OR <rule-2> OR ..
# https://www.openpolicyagent.org/docs/latest/policy-language/#incremental-definitions

# 'Name' tag is valid
is_valid_tag_name(tagname) if {
	tagname == "Name"
}

# lowercase tag names are valid
is_valid_tag_name(tagname) if {
	tagname == lower(tagname)
}

# when resource "tags" is not defined, it's treated as valid
has_only_valid_tags(config) if {
	not "tags" in object.keys(config)
}

# when resource "tags" is defined but it has no value, it's treated as valid
has_only_valid_tags(config) if {
	not "value" in object.keys(config.tags)
}

# when resource "tags" is null, it's treated as valid
has_only_valid_tags(config) if {
	is_null(config.tags.value)
}

# resource has tags, so check that they're are all valid
has_only_valid_tags(config) if {
	every tagname in object.keys(config.tags.value) {
		is_valid_tag_name(tagname)
	}
}

# RULE: deny any invalid tag names
deny_invalid_tag_names contains issue if {
	not has_only_valid_tags(aws_resources[i].config)

	issue := tflint.issue(`resource may not have uppercase tags other than 'Name'`, aws_resources[i].decl_range)
}
