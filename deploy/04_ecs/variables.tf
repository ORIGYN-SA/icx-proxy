variable "container_port" {
  default = 5000
}

variable "container_cpu" {
  description = "The number of cpu units used by the task"
  default     = 256
}

variable "container_memory" {
  description = "The amount (in MiB) of memory used by the task"
  default     = 512
}

variable "service_desired_count" {
  description = "Number of tasks running in parallel"
  default     = 2
}