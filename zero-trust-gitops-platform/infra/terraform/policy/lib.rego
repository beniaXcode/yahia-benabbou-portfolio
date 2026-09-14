package main

# Shared helpers for the rules in this directory. conftest runs against
# `terraform show -json <plan>`, so `input.resource_changes[]` is the shape
# every rule below inspects.

is_create_or_update(actions) if {
	some a in actions
	a == "create"
}

is_create_or_update(actions) if {
	some a in actions
	a == "update"
}

as_array(x) := x if {
	is_array(x)
}

as_array(x) := [x] if {
	not is_array(x)
}

# True when `field` is absent from change.after because it's a reference to
# another resource's attribute that's also being created in this same plan
# (e.g. a KMS key ARN for a key that doesn't exist yet) — legitimately
# "known after apply", not actually missing. Rules that read a field
# expected to be a real value should treat this as compliant, not a
# violation, or every from-scratch `plan` of two co-created resources would
# false-positive on every such reference.
is_unknown_after(rc, field) if {
	object.get(rc.change.after_unknown, field, false) == true
}

# Providers routinely represent "the user didn't set this" as a present
# `null` value rather than an absent key — object.get's default argument
# only covers the latter, so callers checking "is this actually set" need
# both cases.
is_blank(x) if {
	x == null
}

is_blank(x) if {
	x == ""
}
