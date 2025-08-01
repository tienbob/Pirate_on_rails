
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)

import FormValidationController from "./form_validation_controller"
application.register("form-validation", FormValidationController)
