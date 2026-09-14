# C6: every GitHub OIDC trust policy must pin an exact repo:org/repo:ref/
# environment subject and require aud = sts.amazonaws.com — never a
# wildcard `sub`, and never a missing/wrong `aud`.
package main

deny contains msg if {
	some rc in input.resource_changes
	rc.type == "aws_iam_role"
	is_create_or_update(rc.change.actions)
	policy := rc.change.after.assume_role_policy
	is_string(policy)
	doc := json.unmarshal(policy)
	some stmt in as_array(doc.Statement)
	is_github_oidc_statement(stmt)

	cond := object.get(stmt, "Condition", {})
	string_equals := object.get(cond, "StringEquals", {})
	sub := object.get(string_equals, "token.actions.githubusercontent.com:sub", "")
	aud := object.get(string_equals, "token.actions.githubusercontent.com:aud", "")

	violates_sub_or_aud(sub, aud)

	msg := sprintf("%s: GitHub OIDC trust statement has sub=%q aud=%q (C6 — sub must be an exact repo:org/repo:ref-or-environment claim, aud must equal sts.amazonaws.com, neither may be missing or wildcarded)", [rc.address, sub, aud])
}

is_github_oidc_statement(stmt) if {
	principal := object.get(stmt, "Principal", {})
	fed := object.get(principal, "Federated", "")
	contains(fed, "token.actions.githubusercontent.com")
}

violates_sub_or_aud(sub, _) if {
	sub == ""
}

violates_sub_or_aud(sub, _) if {
	contains(sub, "*")
}

violates_sub_or_aud(_, aud) if {
	aud != "sts.amazonaws.com"
}
