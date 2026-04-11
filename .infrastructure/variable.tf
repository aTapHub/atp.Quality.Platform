variable "do_kubernetes_version" {
	description = "Kubernetes version slug for the DigitalOcean cluster"
	type        = string
	default     = ""

	validation {
		condition     = length(trimspace(var.do_kubernetes_version)) > 0
		error_message = "The variable 'do_kubernetes_version' must be set to a valid DigitalOcean Kubernetes version slug."
	}
}
