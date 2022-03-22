locals {
  config_file = try(file("./project-policies/zeta/${terraform.workspace}.yaml"),file("./project-policies/beta/${terraform.workspace}.yaml"),file("./project-policies/alpha/${terraform.workspace}.yaml"))
  config = yamldecode(local.config_file)

  all_taxonomies = tolist([for i in local.config.taxonomies : merge(var.taxonomy_default, i)])
  indexed_taxonomies =  { for taxonomy in local.all_taxonomies: taxonomy.taxonomy_name => taxonomy }
  policies_in_taxonomies = merge([ for tax in local.indexed_taxonomies: { for pol in tax.policies: "${tax.taxonomy_name}-${pol.display_name}" => merge({tax = tax, pol = pol})} ]...)
  members_in_policy = merge([for taxpol in local.policies_in_taxonomies: {
    for role in keys(taxpol.pol.accesses) : "${taxpol.tax.taxonomy_name}-${taxpol.pol.display_name}-${role}" => {
      for person in taxpol.pol.accesses[role] : "${taxpol.tax.taxonomy_name}-${taxpol.pol.display_name}-${role}-${person}" => {
          person = person, role = role, policy_tag = "${taxpol.tax.taxonomy_name}-${taxpol.pol.display_name}"
      }
    }
  } ]...)
  policyRolePerson = merge([ for policyRole in local.members_in_policy : { for policyRolePerson in policyRole : "${policyRolePerson.policy_tag}-${policyRolePerson.role}-${policyRolePerson.person}" => policyRolePerson } ]...)
}


resource "google_project_service" "datacatalog_api" {
  project = local.config.project
  service = "datacatalog.googleapis.com"
  disable_on_destroy = false
}

resource "google_data_catalog_taxonomy" "my_taxonomy" {
  for_each = local.indexed_taxonomies
  provider = google-beta
  project = local.config.project
  region = each.value.taxonomy_region
  display_name = each.value.taxonomy_name
  description = each.value.taxonomy_description
  activated_policy_types = ["FINE_GRAINED_ACCESS_CONTROL"]
  depends_on = [google_project_service.datacatalog_api]
}

resource "google_data_catalog_policy_tag" "basic_policy_tag" {
  for_each = local.policies_in_taxonomies
  provider = google-beta
  taxonomy = google_data_catalog_taxonomy.my_taxonomy[each.value.tax.taxonomy_name].id
  display_name = each.value.pol.display_name
  description = each.value.pol.policy_description
  depends_on = [google_data_catalog_taxonomy.my_taxonomy]
}

resource "google_data_catalog_policy_tag_iam_member" "member" {
  for_each = local.policyRolePerson
  provider = google-beta
  role = each.value.role
  member = each.value.person
  policy_tag = google_data_catalog_policy_tag.basic_policy_tag[each.value.policy_tag].name
  depends_on = [google_data_catalog_policy_tag.basic_policy_tag]
}
