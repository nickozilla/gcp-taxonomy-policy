variable "taxonomy_default" {
  description = "A Taxonomy and associated Policies and roles"
  type = object({
    taxonomy_region = string
    taxonomy_name = string
    taxonomy_description = string
    policies = list(object({
      display_name = string
      policy_description = string
      accesses = map(list(string))
      }
    ))
  })
  default = {
    taxonomy_region = null
    taxonomy_name = null
    taxonomy_description = null
    policies = []
  }
}
